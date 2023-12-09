# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Geo::Replicator do
  context 'with defined events' do
    class DummyReplicator < Gitlab::Geo::Replicator
      event :test
      event :another_test

      protected

      def publish_test(other:)
        true
      end
    end

    context 'event DSL' do
      subject { DummyReplicator }

      describe '.supported_events' do
        it 'expects :test event to be supported' do
          expect(subject.supported_events).to match_array([:test, :another_test])
        end
      end

      describe '.event_supported?' do
        it 'expects a supported event to return true' do
          expect(subject.event_supported?(:test)).to be_truthy
        end

        it 'expect an unsupported event to return false' do
          expect(subject.event_supported?(:something_else)).to be_falsey
        end
      end
    end

    context 'model DSL' do
      class DummyModel
        include ActiveModel::Model

        def self.after_create_commit(*args)
        end

        include Gitlab::Geo::ReplicableModel

        with_replicator DummyReplicator
      end

      subject { DummyModel.new }

      it 'adds replicator method to the model' do
        expect(subject).to respond_to(:replicator)
      end

      it 'instantiates a replicator into the model' do
        expect(subject.replicator).to be_a(DummyReplicator)
      end
    end

    describe '#publish' do
      subject { DummyReplicator.new }

      context 'when geo_self_service_framework feature is disabled' do
        before do
          stub_feature_flags(geo_self_service_framework: false)
        end

        it 'returns nil' do
          expect(subject.publish(:test, other: true)).to be_nil
        end

        it 'does not call create_event' do
          expect(subject).not_to receive(:create_event_with)

          subject.publish(:test, other: true)
        end
      end

      context 'when publishing a supported events with required params' do
        it 'does not raise errors' do
          expect { subject.publish(:test, other: true) }.not_to raise_error
        end
      end

      context 'when publishing unsupported event' do
        it 'raises an argument error' do
          expect { subject.publish(:unsupported) }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
