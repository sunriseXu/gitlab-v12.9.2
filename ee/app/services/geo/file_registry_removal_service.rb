# frozen_string_literal: true

module Geo
  class FileRegistryRemovalService < BaseFileService
    include ::Gitlab::Utils::StrongMemoize

    LEASE_TIMEOUT = 8.hours.freeze

    # It's possible that LfsObject or Ci::JobArtifact record does not exists anymore
    # In this case, you need to pass file_path parameter explicitly
    #
    def initialize(object_type, object_db_id, file_path = nil)
      @object_type = object_type.to_sym
      @object_db_id = object_db_id
      @object_file_path = file_path
    end

    def execute
      log_info('Executing')

      try_obtain_lease do
        log_info('Lease obtained')

        unless file_registry
          log_error('Could not find file_registry')
          break
        end

        if File.exist?(file_path)
          log_info('Unlinking file', file_path: file_path)
          File.unlink(file_path)
        end

        log_info('Removing file registry', file_registry_id: file_registry.id)
        file_registry.destroy

        log_info('Local file & registry removed')
      end
    rescue SystemCallError => e
      log_error('Could not remove file', e.message)
      raise
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def file_registry
      strong_memoize(:file_registry) do
        if job_artifact?
          ::Geo::JobArtifactRegistry.find_by(artifact_id: object_db_id)
        elsif lfs?
          ::Geo::LfsObjectRegistry.find_by(lfs_object_id: object_db_id)
        else
          ::Geo::UploadRegistry.find_by(file_type: object_type, file_id: object_db_id)
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def file_path
      strong_memoize(:file_path) do
        next @object_file_path if @object_file_path
        # When local storage is used, just rely on the existing methods
        next file_uploader.file.path if file_uploader.object_store == ObjectStorage::Store::LOCAL

        # For remote storage more juggling is needed to actually get the full path on disk
        if user_upload?
          upload = file_uploader.upload
          file_uploader.class.absolute_path(upload)
        else
          file_uploader.class.absolute_path(file_uploader.file)
        end
      end
    end

    def file_uploader
      strong_memoize(:file_uploader) do
        case object_type
        when :lfs
          LfsObject.find(object_db_id).file
        when :job_artifact
          Ci::JobArtifact.find(object_db_id).file
        when *Gitlab::Geo::Replication::USER_UPLOADS_OBJECT_TYPES
          Upload.find(object_db_id).retrieve_uploader
        else
          raise NameError, "Unrecognized type: #{object_type}"
        end
      end
    rescue NameError, ActiveRecord::RecordNotFound => err
      log_error('Could not build uploader', err.message)
      raise
    end

    def lease_key
      "file_registry_removal_service:#{object_type}:#{object_db_id}"
    end

    def lease_timeout
      LEASE_TIMEOUT
    end
  end
end
