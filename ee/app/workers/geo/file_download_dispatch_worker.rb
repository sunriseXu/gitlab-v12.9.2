# frozen_string_literal: true

module Geo
  class FileDownloadDispatchWorker < Geo::Scheduler::Secondary::SchedulerWorker # rubocop:disable Scalability/IdempotentWorker
    # rubocop:disable Scalability/CronWorkerContext
    # This worker does not perform work scoped to a context
    include CronjobQueue
    # rubocop:enable Scalability/CronWorkerContext

    private

    # Cannot utilise backoff because there are no events currently being
    # generated for uploads, LFS objects or CI job artifacts so we need to rely
    # upon expensive DB queries to be executed in order to determine if there's
    # work to do.
    #
    # Overrides Geo::Scheduler::SchedulerWorker#should_apply_backoff?
    def should_apply_backoff?
      false
    end

    def max_capacity
      current_node.files_max_capacity
    end

    def schedule_job(object_type, object_db_id)
      job_id = FileDownloadWorker.perform_async(object_type.to_s, object_db_id)

      { id: object_db_id, type: object_type, job_id: job_id } if job_id
    end

    # Pools for new resources to be transferred
    #
    # @return [Array] resources to be transferred
    def load_pending_resources
      resources = find_unsynced_jobs(batch_size: db_retrieve_batch_size)
      remaining_capacity = db_retrieve_batch_size - resources.count

      if remaining_capacity.zero?
        resources
      else
        resources + find_low_priority_jobs(batch_size: remaining_capacity)
      end
    end

    # Get a batch of unsynced resources, taking equal parts from each resource.
    #
    # @return [Array] job arguments of unsynced resources
    def find_unsynced_jobs(batch_size:)
      jobs = job_finders.reduce([]) do |jobs, job_finder|
        jobs << job_finder.find_unsynced_jobs(batch_size: batch_size)
      end

      take_batch(*jobs, batch_size: batch_size)
    end

    # Get a batch of failed and synced-but-missing-on-primary resources, taking
    # equal parts from each resource.
    #
    # @return [Array] job arguments of low priority resources
    def find_low_priority_jobs(batch_size:)
      jobs = job_finders.reduce([]) do |jobs, job_finder|
        jobs << job_finder.find_failed_jobs(batch_size: batch_size)
        jobs << job_finder.find_synced_missing_on_primary_jobs(batch_size: batch_size)
      end

      take_batch(*jobs, batch_size: batch_size)
    end

    def job_finders
      [
        Geo::FileDownloadDispatchWorker::AttachmentJobFinder.new(scheduled_file_ids(Gitlab::Geo::Replication::USER_UPLOADS_OBJECT_TYPES)),
        Geo::FileDownloadDispatchWorker::LfsObjectJobFinder.new(scheduled_file_ids(:lfs)),
        Geo::FileDownloadDispatchWorker::JobArtifactJobFinder.new(scheduled_file_ids(:job_artifact))
      ]
    end

    def scheduled_file_ids(file_types)
      file_types = Array(file_types)
      file_types = file_types.map(&:to_s)

      scheduled_jobs.select { |data| file_types.include?(data[:type].to_s) }.map { |data| data[:id] }
    end
  end
end
