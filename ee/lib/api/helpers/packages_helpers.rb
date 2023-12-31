# frozen_string_literal: true

module API
  module Helpers
    module PackagesHelpers
      MAX_PACKAGE_FILE_SIZE = 50.megabytes.freeze

      def require_packages_enabled!
        not_found! unless ::Gitlab.config.packages.enabled
      end

      def authorize_packages_feature!(subject = user_project)
        forbidden! unless subject.feature_available?(:packages)
      end

      def authorize_read_package!(subject = user_project)
        authorize!(:read_package, subject)
      end

      def authorize_create_package!(subject = user_project)
        authorize!(:create_package, subject)
      end

      def authorize_destroy_package!(subject = user_project)
        authorize!(:destroy_package, subject)
      end

      def authorize_packages_access!(subject = user_project)
        require_packages_enabled!
        authorize_packages_feature!(subject)
        authorize_read_package!(subject)
      end

      def authorize_workhorse!(subject: user_project, has_length: true, maximum_size: MAX_PACKAGE_FILE_SIZE)
        authorize_upload!(subject)

        Gitlab::Workhorse.verify_api_request!(headers)

        status 200
        content_type Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

        params = { has_length: has_length }
        params[:maximum_size] = maximum_size unless has_length
        ::Packages::PackageFileUploader.workhorse_authorize(params)
      end

      def authorize_upload!(subject = user_project)
        authorize_create_package!(subject)
        require_gitlab_workhorse!
      end
    end
  end
end
