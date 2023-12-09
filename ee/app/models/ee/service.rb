# frozen_string_literal: true

module EE
  module Service
    extend ActiveSupport::Concern

    class_methods do
      extend ::Gitlab::Utils::Override

      override :available_services_names
      def available_services_names
        ee_service_names = %w[
          github
          jenkins
          jenkins_deprecated
        ]

        if ::Gitlab.dev_env_or_com?
          ee_service_names.push('gitlab_slack_application')
        end

        (super + ee_service_names).sort_by(&:downcase)
      end
    end
  end
end
