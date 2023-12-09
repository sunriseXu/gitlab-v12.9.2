# frozen_string_literal: true

module EE
  module API
    module Settings
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          override :filter_attributes_using_license
          def filter_attributes_using_license(attrs)
            unless ::License.feature_available?(:repository_mirrors)
              attrs = attrs.except(*::EE::ApplicationSettingsHelper.repository_mirror_attributes)
            end

            unless ::License.feature_available?(:email_additional_text)
              attrs = attrs.except(:email_additional_text)
            end

            unless ::License.feature_available?(:custom_file_templates)
              attrs = attrs.except(:file_template_project_id)
            end

            unless ::License.feature_available?(:default_project_deletion_protection)
              attrs = attrs.except(:default_project_deletion_protection)
            end

            unless License.feature_available?(:adjourned_deletion_for_projects_and_groups)
              attrs = attrs.except(:deletion_adjourned_period)
            end

            unless License.feature_available?(:disable_name_update_for_users)
              attrs = attrs.except(:updating_name_disabled_for_users)
            end

            unless License.feature_available?(:admin_merge_request_approvers_rules)
              attrs = attrs.except(*EE::ApplicationSettingsHelper.merge_request_appovers_rules_attributes)
            end

            unless License.feature_available?(:packages)
              attrs = attrs.except(:npm_package_requests_forwarding)
            end

            attrs
          end
        end
      end
    end
  end
end
