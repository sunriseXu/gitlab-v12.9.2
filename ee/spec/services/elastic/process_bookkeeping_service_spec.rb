# frozen_string_literal: true

require 'spec_helper'

describe Elastic::ProcessBookkeepingService, :clean_gitlab_redis_shared_state do
  around do |example|
    described_class.with_redis do |redis|
      @redis = redis
      example.run
    end
  end

  let(:zset) { 'elastic:incremental:updates:0:zset' }
  let(:redis) { @redis }
  let(:ref_class) { ::Gitlab::Elastic::DocumentReference }

  let(:fake_refs) { Array.new(10) { |i| ref_class.new(Issue, i, "issue_#{i}", 'project_1') } }
  let(:issue) { fake_refs.first }
  let(:issue_spec) { issue.serialize }

  describe '.track' do
    it 'enqueues a record' do
      described_class.track!(issue)

      spec, score = redis.zpopmin(zset)

      expect(spec).to eq(issue_spec)
      expect(score).to eq(1.0)
    end

    it 'enqueues a set of unique records' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)

      spec1, score1 = redis.zpopmin(zset)
      _, score2 = redis.zpopmin(zset)

      expect(score1).to be < score2
      expect(spec1).to eq(issue_spec)
    end

    it 'enqueues 10 identical records as 1 entry' do
      described_class.track!(*([issue] * 10))

      expect(described_class.queue_size).to eq(1)
    end

    it 'deduplicates across multiple inserts' do
      10.times { described_class.track!(issue) }

      expect(described_class.queue_size).to eq(1)
    end
  end

  describe '.queue_size' do
    it 'reports the queue size' do
      expect(described_class.queue_size).to eq(0)

      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)

      expect { redis.zpopmin(zset) }.to change(described_class, :queue_size).by(-1)
    end
  end

  describe '.clear_tracking!' do
    it 'removes all entries from the queue' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)

      described_class.clear_tracking!

      expect(described_class.queue_size).to eq(0)
    end
  end

  describe '#execute' do
    let(:limit) { 5 }

    before do
      stub_const('Elastic::ProcessBookkeepingService::LIMIT', limit)
    end

    it 'submits a batch of documents' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
      expect_processing(*fake_refs[0...limit])

      expect { described_class.new.execute }.to change(described_class, :queue_size).by(-limit)
    end

    it 'retries failed documents' do
      described_class.track!(*fake_refs)
      failed = fake_refs[0]

      expect(described_class.queue_size).to eq(10)
      expect_processing(*fake_refs[0...limit], failures: [failed])

      expect { described_class.new.execute }.to change(described_class, :queue_size).by(-limit + 1)

      serialized, _ = redis.zpopmax(zset)
      expect(ref_class.deserialize(serialized)).to eq(failed)
    end

    it 'discards malformed documents' do
      described_class.track!('Bad')

      expect(described_class.queue_size).to eq(1)
      expect_next_instance_of(::Gitlab::Elastic::BulkIndexer) do |indexer|
        expect(indexer).not_to receive(:process)
      end

      expect { described_class.new.execute }.to change(described_class, :queue_size).by(-1)
    end

    it 'fails, preserving documents, when processing fails with an exception' do
      described_class.track!(issue)

      expect(described_class.queue_size).to eq(1)
      expect_next_instance_of(::Gitlab::Elastic::BulkIndexer) do |indexer|
        expect(indexer).to receive(:process).with(issue) { raise 'Bad' }
      end

      expect { described_class.new.execute }.to raise_error('Bad')
      expect(described_class.queue_size).to eq(1)
    end

    def expect_processing(*refs, failures: [])
      expect_next_instance_of(::Gitlab::Elastic::BulkIndexer) do |indexer|
        refs.each { |ref| expect(indexer).to receive(:process).with(ref) }

        expect(indexer).to receive(:flush) { failures }
      end
    end
  end
end
