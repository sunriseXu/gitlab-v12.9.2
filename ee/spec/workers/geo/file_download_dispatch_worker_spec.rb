# frozen_string_literal: true

require 'spec_helper'

describe Geo::FileDownloadDispatchWorker, :geo, :geo_fdw, :use_sql_query_cache_for_tracking_db do
  include ::EE::GeoHelpers
  include ExclusiveLeaseHelpers

  let(:primary)   { create(:geo_node, :primary, host: 'primary-geo-node') }
  let(:secondary) { create(:geo_node) }

  before do
    stub_current_geo_node(secondary)
    stub_exclusive_lease(renew: true)
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:over_time?).and_return(false)
    end

    WebMock.stub_request(:get, /primary-geo-node/).to_return(status: 200, body: "", headers: {})
  end

  it 'does not schedule anything when tracking database is not configured' do
    create(:lfs_object, :with_file)

    allow(Gitlab::Geo).to receive(:geo_database_configured?) { false }

    expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

    subject.perform

    # We need to unstub here or the DatabaseCleaner will have issues since it
    # will appear as though the tracking DB were not available
    allow(Gitlab::Geo).to receive(:geo_database_configured?).and_call_original
  end

  it 'does not schedule anything when node is disabled' do
    create(:lfs_object, :with_file)

    secondary.enabled = false
    secondary.save

    expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

    subject.perform
  end

  it 'does not schedule duplicated jobs' do
    lfs_object_1 = create(:lfs_object, :with_file)
    lfs_object_2 = create(:lfs_object, :with_file)
    create(:geo_lfs_object_registry, :never_synced, lfs_object: lfs_object_1)
    create(:geo_lfs_object_registry, :failed, lfs_object: lfs_object_2)

    stub_const('Geo::Scheduler::SchedulerWorker::DB_RETRIEVE_BATCH_SIZE', 5)
    secondary.update!(files_max_capacity: 2)
    allow(Gitlab::SidekiqStatus).to receive(:job_status).with([]).and_return([]).twice
    allow(Gitlab::SidekiqStatus).to receive(:job_status).with(%w[123 456]).and_return([true, true], [true, true], [false, false])

    expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_1.id).once.and_return('123')
    expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_2.id).once.and_return('456')

    subject.perform
  end

  it 'does not schedule duplicated jobs because of query cache' do
    lfs_object_1 = create(:lfs_object, :with_file)
    lfs_object_2 = create(:lfs_object, :with_file)
    lfs_object_3 = create(:lfs_object, :with_file)
    create(:geo_lfs_object_registry, :never_synced, lfs_object: lfs_object_1)
    create(:geo_lfs_object_registry, :never_synced, lfs_object: lfs_object_2)
    create(:geo_lfs_object_registry, :never_synced, lfs_object: lfs_object_3)

    stub_const('Geo::Scheduler::SchedulerWorker::DB_RETRIEVE_BATCH_SIZE', 3)
    secondary.update!(files_max_capacity: 3)

    expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_1.id).once do
      Thread.new do
        # Rails will invalidate the query cache if the update happens in the same thread
        Geo::LfsObjectRegistry.update(success: true)
      end
    end

    expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_2.id).once
    expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_3.id).once

    subject.perform
  end

  context 'with attachments (Upload records)' do
    let(:upload) { create(:upload) }

    context 'with geo_file_registry_ssot_sync feature enabled' do
      before do
        stub_feature_flags(geo_file_registry_ssot_sync: true)
      end

      it 'performs Geo::FileDownloadWorker for unsynced attachments' do
        create(:geo_upload_registry, :avatar, :never_synced, file_id: upload.id)

        expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', upload.id)

        subject.perform
      end

      it 'performs Geo::FileDownloadWorker for failed-sync attachments' do
        create(:geo_upload_registry, :avatar, :failed, file_id: upload.id, bytes: 0)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('avatar', upload.id).once.and_return(spy)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced attachments' do
        create(:geo_upload_registry, :avatar, file_id: upload.id, bytes: 1234)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced attachments even with 0 bytes downloaded' do
        create(:geo_upload_registry, :avatar, file_id: upload.id, bytes: 0)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      context 'with a failed file' do
        let(:failed_registry) { create(:geo_upload_registry, :avatar, :failed, file_id: 999) }

        it 'does not stall backfill' do
          unsynced_registry = create(:geo_upload_registry, :avatar, :with_file, :never_synced)

          stub_const('Geo::Scheduler::SchedulerWorker::DB_RETRIEVE_BATCH_SIZE', 1)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('avatar', failed_registry.file_id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced_registry.file_id)

          subject.perform
        end

        it 'retries failed files' do
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end

        it 'does not retry failed files when retry_at is tomorrow' do
          failed_registry = create(:geo_upload_registry, :avatar, :failed, file_id: 999, retry_at: Date.tomorrow)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end

        it 'retries failed files when retry_at is in the past' do
          failed_registry = create(:geo_upload_registry, :avatar, :failed, file_id: 999, retry_at: Date.yesterday)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end
      end

      context 'with Upload files missing on the primary that are marked as synced' do
        let(:synced_upload_with_file_missing_on_primary) { create(:upload) }

        before do
          Geo::UploadRegistry.create!(file_type: :avatar, file_id: synced_upload_with_file_missing_on_primary.id, bytes: 1234, success: true, missing_on_primary: true)
        end

        it 'retries the files if there is spare capacity' do
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', synced_upload_with_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry those files if there is no spare capacity' do
          unsynced_registry = create(:geo_upload_registry, :avatar, :with_file, :never_synced)
          expect(subject).to receive(:db_retrieve_batch_size).and_return(1).twice

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced_registry.file_id)

          subject.perform
        end

        it 'does not retry those files if they are already scheduled' do
          unsynced_registry = create(:geo_upload_registry, :avatar, :with_file, :never_synced)

          scheduled_jobs = [{ type: 'avatar', id: synced_upload_with_file_missing_on_primary.id, job_id: 'foo' }]
          expect(subject).to receive(:scheduled_jobs).and_return(scheduled_jobs).at_least(1)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced_registry.file_id)

          subject.perform
        end
      end
    end

    context 'with geo_file_registry_ssot_sync feature disabled' do
      before do
        stub_feature_flags(geo_file_registry_ssot_sync: false)
      end

      it 'performs Geo::FileDownloadWorker for unsynced attachments' do
        expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', upload.id)

        subject.perform
      end

      it 'performs Geo::FileDownloadWorker for failed-sync attachments' do
        create(:geo_upload_registry, :avatar, :failed, file_id: upload.id, bytes: 0)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('avatar', upload.id).once.and_return(spy)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced attachments' do
        create(:geo_upload_registry, :avatar, file_id: upload.id, bytes: 1234)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced attachments even with 0 bytes downloaded' do
        create(:geo_upload_registry, :avatar, file_id: upload.id, bytes: 0)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      context 'with a failed file' do
        let(:failed_registry) { create(:geo_upload_registry, :avatar, :failed, file_id: 999) }

        it 'does not stall backfill' do
          unsynced = create(:upload)

          stub_const('Geo::Scheduler::SchedulerWorker::DB_RETRIEVE_BATCH_SIZE', 1)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('avatar', failed_registry.file_id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced.id)

          subject.perform
        end

        it 'retries failed files' do
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end

        it 'does not retry failed files when retry_at is tomorrow' do
          failed_registry = create(:geo_upload_registry, :avatar, :failed, file_id: 999, retry_at: Date.tomorrow)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end

        it 'retries failed files when retry_at is in the past' do
          failed_registry = create(:geo_upload_registry, :avatar, :failed, file_id: 999, retry_at: Date.yesterday)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', failed_registry.file_id)

          subject.perform
        end
      end

      context 'with Upload files missing on the primary that are marked as synced' do
        let(:synced_upload_with_file_missing_on_primary) { create(:upload) }

        before do
          Geo::UploadRegistry.create!(file_type: :avatar, file_id: synced_upload_with_file_missing_on_primary.id, bytes: 1234, success: true, missing_on_primary: true)
        end

        it 'retries the files if there is spare capacity' do
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', synced_upload_with_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry those files if there is no spare capacity' do
          unsynced_upload = create(:upload)
          expect(subject).to receive(:db_retrieve_batch_size).and_return(1).twice

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced_upload.id)

          subject.perform
        end

        it 'does not retry those files if they are already scheduled' do
          unsynced_upload = create(:upload)

          scheduled_jobs = [{ type: 'avatar', id: synced_upload_with_file_missing_on_primary.id, job_id: 'foo' }]
          expect(subject).to receive(:scheduled_jobs).and_return(scheduled_jobs).at_least(1)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('avatar', unsynced_upload.id)

          subject.perform
        end
      end
    end
  end

  context 'with LFS objects' do
    let!(:lfs_object_local_store) { create(:lfs_object, :with_file) }
    let!(:lfs_object_remote_store) { create(:lfs_object, :with_file, :object_storage) }

    before do
      stub_lfs_object_storage
    end

    context 'with files missing on the primary' do
      let!(:lfs_object_file_missing_on_primary) { create(:lfs_object, :with_file) }

      context 'with lfs_object_registry entries' do
        before do
          create(:geo_lfs_object_registry, :never_synced, lfs_object: lfs_object_local_store)
          create(:geo_lfs_object_registry, :failed, lfs_object: lfs_object_remote_store)
          Geo::LfsObjectRegistry.create!(lfs_object_id: lfs_object_file_missing_on_primary.id, bytes: 1234, success: true, missing_on_primary: true)
        end

        it 'enqueues file downloads if there is spare capacity' do
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_local_store.id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_file_missing_on_primary.id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_remote_store.id)

          subject.perform
        end

        it 'does not retry those files if there is no spare capacity' do
          expect(subject).to receive(:db_retrieve_batch_size).and_return(1).twice

          expect(Geo::FileDownloadWorker).to receive(:perform_async).once

          subject.perform
        end

        it 'does not retry those files if they are already scheduled' do
          scheduled_jobs = [{ type: 'lfs', id: lfs_object_file_missing_on_primary.id, job_id: 'foo' }]
          expect(subject).to receive(:scheduled_jobs).and_return(scheduled_jobs).at_least(1)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_local_store.id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('lfs', lfs_object_remote_store.id)

          subject.perform
        end
      end

      context 'with no lfs_object_registry entries' do
        it 'does not enqueue file downloads' do
          expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

          subject.perform
        end
      end
    end
  end

  context 'with job artifacts' do
    context 'with geo_job_artifact_registry_ssot_sync feature enabled' do
      before do
        stub_feature_flags(geo_job_artifact_registry_ssot_sync: true)
      end

      it 'performs Geo::FileDownloadWorker for unsynced job artifacts' do
        registry = create(:geo_job_artifact_registry, :with_artifact, :never_synced)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('job_artifact', registry.artifact_id).once.and_return(spy)

        subject.perform
      end

      it 'performs Geo::FileDownloadWorker for failed-sync job artifacts' do
        registry = create(:geo_job_artifact_registry, :with_artifact, :never_synced)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('job_artifact', registry.artifact_id).once.and_return(spy)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced job artifacts' do
        registry = create(:geo_job_artifact_registry, :with_artifact, bytes: 1234, success: true)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)
          .with('job_artifact', registry.artifact_id)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced job artifacts even with 0 bytes downloaded' do
        registry = create(:geo_job_artifact_registry, :with_artifact, bytes: 0, success: true)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)
          .with('job_artifact', registry.artifact_id)

        subject.perform
      end

      it 'does not retry failed artifacts when retry_at is tomorrow' do
        registry = create(:geo_job_artifact_registry, :with_artifact, :failed, retry_at: Date.tomorrow)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)
         .with('job_artifact', registry.artifact_id)

        subject.perform
      end

      it 'retries failed artifacts when retry_at is in the past' do
        registry = create(:geo_job_artifact_registry, :with_artifact, :failed, retry_at: Date.yesterday)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('job_artifact', registry.artifact_id).once.and_return(spy)

        subject.perform
      end

      context 'with files missing on the primary that are marked as synced' do
        let!(:artifact_file_missing_on_primary) { create(:ci_job_artifact) }
        let!(:artifact_registry) { create(:geo_job_artifact_registry, artifact_id: artifact_file_missing_on_primary.id, bytes: 1234, success: true, missing_on_primary: true) }

        it 'retries the files if there is spare capacity' do
          registry = create(:geo_job_artifact_registry, :with_artifact, :never_synced)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', registry.artifact_id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'retries failed files with retry_at in the past' do
          artifact_registry.update!(retry_at: Date.yesterday)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry files with later retry_at' do
          artifact_registry.update!(retry_at: Date.tomorrow)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry those files if there is no spare capacity' do
          registry = create(:geo_job_artifact_registry, :with_artifact, :never_synced)

          expect(subject).to receive(:db_retrieve_batch_size).and_return(1).twice
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', registry.artifact_id)

          subject.perform
        end

        it 'does not retry those files if they are already scheduled' do
          registry = create(:geo_job_artifact_registry, :with_artifact, :never_synced)

          scheduled_jobs = [{ type: 'job_artifact', id: artifact_file_missing_on_primary.id, job_id: 'foo' }]
          expect(subject).to receive(:scheduled_jobs).and_return(scheduled_jobs).at_least(1)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', registry.artifact_id)

          subject.perform
        end
      end
    end

    context 'with geo_job_artifact_registry_ssot_sync feature disabled' do
      before do
        stub_feature_flags(geo_job_artifact_registry_ssot_sync: false)
      end

      it 'performs Geo::FileDownloadWorker for unsynced job artifacts' do
        artifact = create(:ci_job_artifact)

        expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact.id)

        subject.perform
      end

      it 'performs Geo::FileDownloadWorker for failed-sync job artifacts' do
        artifact = create(:ci_job_artifact)

        create(:geo_job_artifact_registry, artifact_id: artifact.id, bytes: 0, success: false)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('job_artifact', artifact.id).once.and_return(spy)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced job artifacts' do
        artifact = create(:ci_job_artifact)

        create(:geo_job_artifact_registry, artifact_id: artifact.id, bytes: 1234, success: true)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      it 'does not perform Geo::FileDownloadWorker for synced job artifacts even with 0 bytes downloaded' do
        artifact = create(:ci_job_artifact)

        create(:geo_job_artifact_registry, artifact_id: artifact.id, bytes: 0, success: true)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async)

        subject.perform
      end

      it 'does not retry failed artifacts when retry_at is tomorrow' do
        failed_registry = create(:geo_job_artifact_registry, :with_artifact, bytes: 0, success: false, retry_at: Date.tomorrow)

        expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('job_artifact', failed_registry.artifact_id)

        subject.perform
      end

      it 'retries failed artifacts when retry_at is in the past' do
        failed_registry = create(:geo_job_artifact_registry, :with_artifact, success: false, retry_at: Date.yesterday)

        expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', failed_registry.artifact_id)

        subject.perform
      end

      context 'with files missing on the primary that are marked as synced' do
        let!(:artifact_file_missing_on_primary) { create(:ci_job_artifact) }
        let!(:artifact_registry) { create(:geo_job_artifact_registry, artifact_id: artifact_file_missing_on_primary.id, bytes: 1234, success: true, missing_on_primary: true) }

        it 'retries the files if there is spare capacity' do
          artifact = create(:ci_job_artifact)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact.id)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'retries failed files with retry_at in the past' do
          artifact_registry.update!(retry_at: Date.yesterday)

          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry files with later retry_at' do
          artifact_registry.update!(retry_at: Date.tomorrow)

          expect(Geo::FileDownloadWorker).not_to receive(:perform_async).with('job_artifact', artifact_file_missing_on_primary.id)

          subject.perform
        end

        it 'does not retry those files if there is no spare capacity' do
          artifact = create(:ci_job_artifact)

          expect(subject).to receive(:db_retrieve_batch_size).and_return(1).twice
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact.id)

          subject.perform
        end

        it 'does not retry those files if they are already scheduled' do
          artifact = create(:ci_job_artifact)

          scheduled_jobs = [{ type: 'job_artifact', id: artifact_file_missing_on_primary.id, job_id: 'foo' }]
          expect(subject).to receive(:scheduled_jobs).and_return(scheduled_jobs).at_least(1)
          expect(Geo::FileDownloadWorker).to receive(:perform_async).with('job_artifact', artifact.id)

          subject.perform
        end
      end
    end
  end

  context 'backoff time' do
    let(:cache_key) { "#{described_class.name.underscore}:skip" }

    it 'does not set the back off time when there are no pending items' do
      expect(Rails.cache).not_to receive(:write).with(cache_key, true, expires_in: 300.seconds)

      subject.perform
    end
  end

  # Test the case where we have:
  #
  # 1. A total of 10 files in the queue, and we can load a maximimum of 5 and send 2 at a time.
  # 2. We send 2, wait for 1 to finish, and then send again.
  it 'attempts to load a new batch without pending downloads' do
    stub_const('Geo::Scheduler::SchedulerWorker::DB_RETRIEVE_BATCH_SIZE', 5)
    secondary.update!(files_max_capacity: 2)
    result_object = double(:result, success: true, bytes_downloaded: 100, primary_missing_file: false)
    allow_any_instance_of(::Gitlab::Geo::Replication::BaseTransfer).to receive(:download_from_primary).and_return(result_object)

    create_list(:geo_lfs_object_registry, 2, :with_lfs_object, :never_synced)
    create_list(:geo_upload_registry, 2, :avatar, :with_file, :never_synced)
    create_list(:geo_upload_registry, 2, :attachment, :with_file, :never_synced)
    create(:geo_upload_registry, :favicon, :with_file, :never_synced)
    create(:geo_upload_registry, :import_export, :with_file, :never_synced)
    create(:geo_upload_registry, :personal_file, :with_file, :never_synced)
    create(:geo_job_artifact_registry, :with_artifact, :never_synced)

    expect(Geo::FileDownloadWorker).to receive(:perform_async).exactly(10).times.and_call_original
    # For 10 downloads, we expect four database reloads:
    # 1. Load the first batch of 5.
    # 2. 4 get sent out, 1 remains. This triggers another reload, which loads in the next 5.
    # 3. Those 4 get sent out, and 1 remains.
    # 3. Since the second reload filled the pipe with 4, we need to do a final reload to ensure
    #    zero are left.
    expect(subject).to receive(:load_pending_resources).exactly(4).times.and_call_original

    Sidekiq::Testing.inline! do
      subject.perform
    end
  end

  context 'when node has namespace restrictions', :request_store do
    let(:synced_group) { create(:group) }
    let(:project_in_synced_group) { create(:project, group: synced_group) }
    let(:unsynced_project) { create(:project) }

    before do
      secondary.update!(selective_sync_type: 'namespaces', namespaces: [synced_group])

      allow(ProjectCacheWorker).to receive(:perform_async).and_return(true)
      allow(::Gitlab::Geo).to receive(:current_node).and_call_original
      Rails.cache.write(:current_node, secondary.to_json)
      allow(::GeoNode).to receive(:current_node).and_return(secondary)
    end

    context 'when geo_job_artifact_registry_ssot_sync feature is disabled' do
      before do
        stub_feature_flags(geo_job_artifact_registry_ssot_sync: false)
      end

      it 'does not perform Geo::FileDownloadWorker for job artifact that does not belong to selected namespaces to replicate' do
        create(:ci_job_artifact, project: unsynced_project)
        job_artifact_in_synced_group = create(:ci_job_artifact, project: project_in_synced_group)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('job_artifact', job_artifact_in_synced_group.id).once.and_return(spy)

        subject.perform
      end
    end

    context 'with geo_file_registry_ssot_sync feature disabled' do
      before do
        stub_feature_flags(geo_file_registry_ssot_sync: false)
      end

      it 'does not perform Geo::FileDownloadWorker for upload objects that do not belong to selected namespaces to replicate' do
        avatar = fixture_file_upload('spec/fixtures/dk.png')
        avatar_in_synced_group = create(:upload, model: synced_group, path: avatar)
        create(:upload, model: create(:group), path: avatar)
        avatar_in_project_in_synced_group = create(:upload, model: project_in_synced_group, path: avatar)
        create(:upload, model: unsynced_project, path: avatar)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('avatar', avatar_in_project_in_synced_group.id).once.and_return(spy)

        expect(Geo::FileDownloadWorker).to receive(:perform_async)
          .with('avatar', avatar_in_synced_group.id).once.and_return(spy)

        subject.perform
      end
    end
  end
end
