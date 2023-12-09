# frozen_string_literal: true

module DesignManagement
  class NewVersionWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    feature_category :design_management
    # Declare this worker as memory bound due to
    # `GenerateImageVersionsService` resizing designs
    worker_resource_boundary :memory

    def perform(version_id)
      version = DesignManagement::Version.find(version_id)

      add_system_note(version)
      generate_image_versions(version)
    rescue ActiveRecord::RecordNotFound => e
      Sidekiq.logger.warn(e)
    end

    private

    def add_system_note(version)
      SystemNoteService.design_version_added(version)
    end

    def generate_image_versions(version)
      return unless ::Feature.enabled?(:design_management_resize_images, version.project)

      DesignManagement::GenerateImageVersionsService.new(version).execute
    end
  end
end
