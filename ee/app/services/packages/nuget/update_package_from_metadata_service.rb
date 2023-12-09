# frozen_string_literal: true

module Packages
  module Nuget
    class UpdatePackageFromMetadataService
      include Gitlab::Utils::StrongMemoize

      InvalidMetadataError = Class.new(StandardError)

      def initialize(package_file)
        @package_file = package_file
      end

      def execute
        raise InvalidMetadataError.new('package name and/or package version not found in metadata') unless valid_metadata?

        @package_file.transaction do
          @package_file.update!(
            file_name: package_filename,
            file: @package_file.file
          )

          if existing_package_id
            link_to_existing_package
          else
            update_linked_package
          end
        end
      end

      private

      def valid_metadata?
        package_name.present? && package_version.present?
      end

      def link_to_existing_package
        package_to_destroy = @package_file.package
        @package_file.update!(package_id: existing_package_id)
        package_to_destroy.destroy!
      end

      def update_linked_package
        return unless package_name && package_version

        @package_file.package.update!(
          name: package_name,
          version: package_version
        )
      end

      def existing_package_id
        strong_memoize(:existing_package_id) do
          @package_file.project.packages
                               .nuget
                               .with_name(package_name)
                               .with_version(package_version)
                               .pluck_primary_key
                               .first
        end
      end

      def package_name
        metadata[:package_name]
      end

      def package_version
        metadata[:package_version]
      end

      def metadata
        strong_memoize(:metadata) do
          ::Packages::Nuget::MetadataExtractionService.new(@package_file.id).execute
        end
      end

      def package_filename
        "#{package_name.downcase}.#{package_version.downcase}.nupkg"
      end
    end
  end
end
