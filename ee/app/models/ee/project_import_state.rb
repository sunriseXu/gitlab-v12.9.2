# frozen_string_literal: true

module EE
  module ProjectImportState
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      BACKOFF_PERIOD = 24.seconds
      JITTER = 6.seconds

      delegate :mirror?, to: :project

      before_validation :set_next_execution_to_now, on: :create

      state_machine :status, initial: :none do
        before_transition [:none, :finished, :failed] => :scheduled do |state, _|
          state.last_update_scheduled_at = Time.now
        end

        before_transition scheduled: :started do |state, _|
          state.last_update_started_at = Time.now
        end

        before_transition scheduled: :failed do |state, _|
          if state.mirror?
            state.last_update_at = Time.now
            state.set_next_execution_to_now
          end
        end

        after_transition started: :failed do |state, _|
          if state.mirror? && state.retry_limit_exceeded?
            ::NotificationService.new.mirror_was_hard_failed(state.project)
          end
        end

        after_transition [:scheduled, :started] => [:finished, :failed] do |state, _|
          ::Gitlab::Mirror.decrement_capacity(state.project_id) if state.mirror?
        end

        before_transition started: :failed do |state, _|
          if state.mirror?
            state.last_update_at = Time.now
            state.increment_retry_count
            state.set_next_execution_timestamp
          end
        end

        before_transition started: :finished do |state, _|
          if state.mirror?
            timestamp = Time.now
            state.last_update_at = timestamp
            state.last_successful_update_at = timestamp

            state.reset_retry_count
            state.set_next_execution_timestamp
          end
        end

        after_transition started: :finished do |state, _|
          if state.project.use_elasticsearch?
            state.run_after_commit do
              last_indexed_commit = state.project.index_status&.last_commit
              ElasticCommitIndexerWorker.perform_async(state.project_id, last_indexed_commit)
            end
          end
        end

        after_transition [:finished, :failed] => [:scheduled, :started] do |state, _|
          ::Gitlab::Mirror.increment_capacity(state.project_id) if state.mirror?
        end
      end
    end

    override :in_progress?
    def in_progress?
      # If we're importing while we do have a repository, we're simply updating the mirror.
      super && !project.mirror_with_content?
    end

    def mirror_waiting_duration
      return unless mirror?

      (last_update_started_at.to_i - last_update_scheduled_at.to_i).seconds
    end

    def mirror_update_duration
      return unless mirror?

      (last_update_at.to_i - last_update_started_at.to_i).seconds
    end

    def updating_mirror?
      (scheduled? || started?) && project.mirror_with_content?
    end

    def mirror_update_due?
      return false unless project.mirror_with_content?
      return false if project.archived?
      return false if hard_failed?
      return false if updating_mirror?

      next_execution_timestamp <= Time.now
    end

    def last_update_status
      return unless state_updated?

      if last_update_at == last_successful_update_at
        :success
      else
        :failed
      end
    end

    def last_update_succeeded?
      last_update_status == :success
    end

    def last_update_failed?
      last_update_status == :failed
    end

    def ever_updated_successfully?
      state_updated? && last_successful_update_at
    end

    def reset_retry_count
      self.retry_count = 0
    end

    def increment_retry_count
      self.retry_count += 1
    end

    # We schedule the next sync time based on the duration of the
    # last mirroring period and add it a fixed backoff period with a random jitter
    def set_next_execution_timestamp
      timestamp = Time.now
      retry_factor = [1, self.retry_count].max
      delay = [base_delay(timestamp), ::Gitlab::Mirror.min_delay].max
      delay = [delay * retry_factor, ::Gitlab::Mirror.max_delay].min

      self.next_execution_timestamp = timestamp + delay
    end

    def force_import_job!
      return if mirror_update_due? || updating_mirror?

      set_next_execution_to_now(prioritized: true)
      reset_retry_count if hard_failed?

      save!

      UpdateAllMirrorsWorker.perform_async
    end

    def set_next_execution_to_now(prioritized: false)
      return unless mirror?

      self.next_execution_timestamp = prioritized ? 5.minutes.ago : Time.now
    end

    def retry_limit_exceeded?
      self.retry_count > ::Gitlab::Mirror::MAX_RETRY
    end
    alias_method :hard_failed?, :retry_limit_exceeded?

    private

    def state_updated?
      mirror? && last_update_at
    end

    def base_delay(timestamp)
      return 0 unless self.last_update_started_at

      duration = timestamp - self.last_update_started_at

      (BACKOFF_PERIOD + rand(JITTER)) * duration.seconds
    end
  end
end
