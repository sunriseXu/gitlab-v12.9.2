# frozen_string_literal: true

class ElasticIndexBulkCronWorker
  include ApplicationWorker
  include Gitlab::ExclusiveLeaseHelpers

  # There is no onward scheduling and this cron handles work from across the
  # application, so there's no useful context to add.
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext

  feature_category :global_search
  idempotent!
  urgency :throttled

  def perform
    in_lock(self.class.name.underscore, ttl: 10.minutes, retries: 10, sleep_sec: 1) do
      Elastic::ProcessBookkeepingService.new.execute
    end
  rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
    # We're scheduled on a cronjob, so nothing to do here
  end
end
