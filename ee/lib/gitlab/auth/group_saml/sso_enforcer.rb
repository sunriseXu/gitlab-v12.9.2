# frozen_string_literal: true

module Gitlab
  module Auth
    module GroupSaml
      class SsoEnforcer
        attr_reader :saml_provider

        def initialize(saml_provider)
          @saml_provider = saml_provider
        end

        def update_session
          SsoState.new(saml_provider.id).update_active(DateTime.now)
        end

        def active_session?
          SsoState.new(saml_provider.id).active?
        end

        def access_restricted?
          saml_enforced? && !active_session? && ::Feature.enabled?(:enforced_sso_requires_session, group)
        end

        def self.group_access_restricted?(group)
          return false unless group
          return false unless group.root_ancestor
          return false unless ::Feature.enabled?(:enforced_sso_requires_session, group.root_ancestor)

          saml_provider = group.root_ancestor.saml_provider

          return false unless saml_provider

          new(saml_provider).access_restricted?
        end

        private

        def saml_enforced?
          saml_provider&.enforced_sso?
        end

        def group
          saml_provider&.group
        end
      end
    end
  end
end
