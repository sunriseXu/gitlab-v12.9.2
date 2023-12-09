# frozen_string_literal: true

module Geo
  class EventLog < ApplicationRecord
    include Geo::Model
    include ::EachBatch

    EVENT_CLASSES = %w[Geo::CacheInvalidationEvent
                       Geo::RepositoryCreatedEvent
                       Geo::RepositoryUpdatedEvent
                       Geo::RepositoryDeletedEvent
                       Geo::RepositoryRenamedEvent
                       Geo::RepositoriesChangedEvent
                       Geo::ResetChecksumEvent
                       Geo::HashedStorageMigratedEvent
                       Geo::HashedStorageAttachmentsEvent
                       Geo::LfsObjectDeletedEvent
                       Geo::JobArtifactDeletedEvent
                       Geo::UploadDeletedEvent
                       Geo::ContainerRepositoryUpdatedEvent
                       Geo::Event].freeze

    belongs_to :cache_invalidation_event,
      class_name: 'Geo::CacheInvalidationEvent',
      foreign_key: :cache_invalidation_event_id

    belongs_to :repository_created_event,
      class_name: 'Geo::RepositoryCreatedEvent',
      foreign_key: :repository_created_event_id

    belongs_to :repository_updated_event,
      class_name: 'Geo::RepositoryUpdatedEvent',
      foreign_key: :repository_updated_event_id

    belongs_to :repository_deleted_event,
      class_name: 'Geo::RepositoryDeletedEvent',
      foreign_key: :repository_deleted_event_id

    belongs_to :repository_renamed_event,
      class_name: 'Geo::RepositoryRenamedEvent',
      foreign_key: :repository_renamed_event_id

    belongs_to :repositories_changed_event,
      class_name: 'Geo::RepositoriesChangedEvent',
      foreign_key: :repositories_changed_event_id

    belongs_to :hashed_storage_migrated_event,
      class_name: 'Geo::HashedStorageMigratedEvent',
      foreign_key: :hashed_storage_migrated_event_id

    belongs_to :hashed_storage_attachments_event,
      class_name: 'Geo::HashedStorageAttachmentsEvent',
      foreign_key: :hashed_storage_attachments_event_id

    belongs_to :lfs_object_deleted_event,
      class_name: 'Geo::LfsObjectDeletedEvent',
      foreign_key: :lfs_object_deleted_event_id

    belongs_to :job_artifact_deleted_event,
      class_name: 'Geo::JobArtifactDeletedEvent',
      foreign_key: :job_artifact_deleted_event_id

    belongs_to :upload_deleted_event,
      class_name: 'Geo::UploadDeletedEvent',
      foreign_key: :upload_deleted_event_id

    belongs_to :reset_checksum_event,
      class_name: 'Geo::ResetChecksumEvent',
      foreign_key: :reset_checksum_event_id

    belongs_to :container_repository_updated_event,
      class_name: 'Geo::ContainerRepositoryUpdatedEvent',
      foreign_key: :container_repository_updated_event_id

    belongs_to :event,
      class_name: 'Geo::Event',
      foreign_key: :geo_event_id

    def self.latest_event
      order(id: :desc).first
    end

    def self.next_unprocessed_event
      last_processed = Geo::EventLogState.last_processed
      return first unless last_processed

      where('id > ?', last_processed.event_id).first
    end

    def self.event_classes
      EVENT_CLASSES.map(&:constantize)
    end

    def self.includes_events
      includes(reflections.keys)
    end

    def event
      repository_created_event ||
        repository_updated_event ||
        repository_deleted_event ||
        repository_renamed_event ||
        repositories_changed_event ||
        hashed_storage_migrated_event ||
        hashed_storage_attachments_event ||
        lfs_object_deleted_event ||
        job_artifact_deleted_event ||
        upload_deleted_event ||
        reset_checksum_event ||
        cache_invalidation_event ||
        container_repository_updated_event
    end

    def project_id
      event.try(:project_id)
    end
  end
end
