# frozen_string_literal: true

module EE
  module Keys
    module CreateService
      def execute
        super.tap do |key|
          log_audit_event(key)
        end
      end

      def log_audit_event(key)
        audit_event_service.for_user(key.title).security_event
      end

      def audit_event_service
        ::AuditEventService.new(user,
                                user,
                                action: :custom,
                                custom_message: 'Added SSH key',
                                ip_address: @ip_address) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end
    end
  end
end
