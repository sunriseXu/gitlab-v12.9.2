# frozen_string_literal: true

require 'spec_helper'

describe Geo::RepositorySyncWorker, :geo, :clean_gitlab_redis_cache do
  include ::EE::GeoHelpers

  let!(:primary) { create(:geo_node, :primary) }
  let!(:secondary) { create(:geo_node) }
  let!(:synced_group) { create(:group) }
  let!(:project_in_synced_group) { create(:project, group: synced_group) }
  let!(:unsynced_project) { create(:project) }
  let(:healthy_shard_name) { project_in_synced_group.repository.storage }
  let(:design_worker) { Geo::DesignRepositoryShardSyncWorker }

  before do
    stub_current_geo_node(secondary)
  end

  around do |example|
    Sidekiq::Testing.inline! { example.run }
  end

  shared_examples '#perform' do |worker|
    context 'additional shards' do
      it 'skips backfill for repositories on other shards' do
        create(:project, :broken_storage, group: synced_group)
        unhealthy_dirty = create(:project, :broken_storage, group: synced_group)
        create(:geo_project_registry, :synced, :repository_dirty, project: unhealthy_dirty)

        allow(Gitlab::GitalyClient).to receive(:call) do
          raise GRPC::Unavailable.new('No Gitaly available')
        end

        expect(worker).not_to receive(:perform_async).with('broken')
        expect(design_worker).not_to receive(:perform_async).with('broken')

        subject.perform
      end

      it 'skips backfill for projects on shards excluded by selective sync' do
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: [healthy_shard_name])

        # Report both shards as healthy
        expect(Gitlab::HealthChecks::GitalyCheck).to receive(:readiness)
          .and_return([result(true, healthy_shard_name), result(true, 'broken')])

        expect(worker).to receive(:perform_async).with('default')
        expect(design_worker).to receive(:perform_async).with('default')
        expect(worker).not_to receive(:perform_async).with('broken')
        expect(design_worker).not_to receive(:perform_async).with('broken')

        subject.perform
      end

      it 'skips backfill for projects on missing shards' do
        missing_not_synced = create(:project, group: synced_group)
        missing_not_synced.update_column(:repository_storage, 'unknown')
        missing_dirty = create(:project, group: synced_group)
        missing_dirty.update_column(:repository_storage, 'unknown')

        create(:geo_project_registry, :synced, :repository_dirty, project: missing_dirty)

        # hide the 'broken' storage for this spec
        stub_storage_settings({})

        expect(worker).to receive(:perform_async).with(project_in_synced_group.repository.storage)
        expect(design_worker).to receive(:perform_async).with(project_in_synced_group.repository.storage)
        expect(worker).not_to receive(:perform_async).with('unknown')
        expect(design_worker).not_to receive(:perform_async).with('unknown')

        subject.perform
      end

      it 'skips backfill for projects with downed Gitaly server' do
        create(:project, :broken_storage, group: synced_group)
        unhealthy_dirty = create(:project, :broken_storage, group: synced_group)

        create(:geo_project_registry, :synced, :repository_dirty, project: unhealthy_dirty)

        # Report only one healthy shard
        expect(Gitlab::HealthChecks::GitalyCheck).to receive(:readiness)
          .and_return([result(true, healthy_shard_name), result(false, 'broken')])

        expect(worker).to receive(:perform_async).with(healthy_shard_name)
        expect(design_worker).to receive(:perform_async).with(healthy_shard_name)
        expect(worker).not_to receive(:perform_async).with('broken')
        expect(design_worker).not_to receive(:perform_async).with('broken')

        subject.perform
      end
    end
  end

  context 'when geo_streaming_results_repository_sync flag is enabled', :geo_fdw do
    before do
      stub_feature_flags(geo_streaming_results_repository_sync: true)
    end

    include_examples '#perform', Geo::Secondary::RepositoryBackfillWorker
  end

  context 'when geo_streaming_results_repository_sync flag is disabled' do
    before do
      stub_feature_flags(geo_streaming_results_repository_sync: false)
    end

    include_examples '#perform', Geo::RepositoryShardSyncWorker
  end

  def result(success, shard)
    Gitlab::HealthChecks::Result.new('gitaly_check', success, nil, { shard: shard })
  end
end
