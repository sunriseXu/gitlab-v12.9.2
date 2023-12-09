# frozen_string_literal: true

FactoryBot.define do
  factory :geo_node_status do
    geo_node
    storage_shards { StorageShard.all }

    trait :healthy do
      status_message { nil }
      attachments_count { 329 }
      attachments_failed_count { 13 }
      attachments_synced_count { 141 }
      attachments_synced_missing_on_primary_count { 89 }
      lfs_objects_count { 256 }
      lfs_objects_failed_count { 12 }
      lfs_objects_synced_count { 123 }
      lfs_objects_synced_missing_on_primary_count { 90 }
      job_artifacts_count { 580 }
      job_artifacts_failed_count { 3 }
      job_artifacts_synced_count { 577 }
      job_artifacts_synced_missing_on_primary_count { 91 }
      container_repositories_count { 400 }
      container_repositories_failed_count { 3 }
      container_repositories_synced_count { 200 }
      design_repositories_count { 400 }
      design_repositories_failed_count { 3 }
      design_repositories_synced_count { 200 }
      projects_count { 10 }
      repositories_synced_count { 5 }
      repositories_failed_count { 0 }
      wikis_synced_count { 4 }
      wikis_failed_count { 1 }
      repositories_checksummed_count { 600 }
      repositories_checksum_failed_count { 120 }
      wikis_checksummed_count { 585 }
      wikis_checksum_failed_count { 55 }
      repositories_verified_count { 501 }
      repositories_verification_failed_count { 100 }
      repositories_checksum_mismatch_count { 15 }
      wikis_verified_count { 499 }
      wikis_verification_failed_count { 99 }
      wikis_checksum_mismatch_count { 10 }
      repositories_retrying_verification_count { 25 }
      wikis_retrying_verification_count { 3 }
      repositories_checked_failed_count { 1 }
      last_event_id { 2 }
      last_event_timestamp { Time.now.to_i }
      cursor_last_event_id { 1 }
      cursor_last_event_timestamp { Time.now.to_i }
      last_successful_status_check_timestamp { 2.minutes.ago }
      version { Gitlab::VERSION }
      revision { Gitlab.revision }
    end

    trait :unhealthy do
      status_message { "Could not connect to Geo node - HTTP Status Code: 401 Unauthorized\nTest" }
    end
  end
end
