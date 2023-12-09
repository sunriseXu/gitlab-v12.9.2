# frozen_string_literal: true

require 'spec_helper'

describe ElasticNamespaceIndexerWorker, :elastic do
  subject { described_class.new }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
    stub_ee_application_setting(elasticsearch_limit_indexing: true)
  end

  it 'returns true if ES disabled' do
    stub_ee_application_setting(elasticsearch_indexing: false)

    expect(ElasticIndexerWorker).not_to receive(:perform_async)

    expect(subject.perform(1, "index")).to be_truthy
  end

  it 'returns true if limited indexing is not enabled' do
    stub_ee_application_setting(elasticsearch_limit_indexing: false)

    expect(ElasticIndexerWorker).not_to receive(:perform_async)

    expect(subject.perform(1, "index")).to be_truthy
  end

  describe 'indexing and deleting' do
    let_it_be(:namespace) { create :namespace }
    let(:projects) { create_list :project, 3, namespace: namespace }

    it 'indexes all projects belonging to the namespace' do
      args = projects.map { |project| [:index, project.class.to_s, project.id, project.es_id] }
      expect(ElasticIndexerWorker).to receive(:bulk_perform_async).with(args)

      subject.perform(namespace.id, :index)
    end

    it 'deletes all projects belonging to the namespace' do
      args = projects.map { |project| [:delete, project.class.to_s, project.id, project.es_id] }
      expect(ElasticIndexerWorker).to receive(:bulk_perform_async).with(args)

      subject.perform(namespace.id, :delete)
    end
  end
end
