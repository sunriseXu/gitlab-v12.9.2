# frozen_string_literal: true

module API
  class AuditEvents < ::Grape::API
    include ::API::PaginationParams

    before do
      authenticated_as_admin!
      forbidden! unless ::License.feature_available?(:admin_audit_log)
    end

    resources :audit_events do
      desc 'Get the list of audit events' do
        success EE::API::Entities::AuditEvent
      end
      params do
        optional :entity_type, type: String, desc: 'Return list of audit events for the specified entity type', values: AuditLogFinder::VALID_ENTITY_TYPES
        optional :entity_id, type: Integer
        given :entity_id do
          requires :entity_type, type: String
        end
        optional :created_after, type: DateTime, desc: 'Return audit events created after the specified time'
        optional :created_before, type: DateTime, desc: 'Return audit events created before the specified time'

        use :pagination
      end
      get do
        audit_events = AuditLogFinder.new(params).execute

        present paginate(audit_events), with: EE::API::Entities::AuditEvent
      end

      desc 'Get single audit event' do
        success EE::API::Entities::AuditEvent
      end
      params do
        requires :id, type: Integer, desc: 'The ID of audit event'
      end
      get ':id' do
        audit_event = AuditEvent.find_by_id(params[:id])
        not_found!('Audit Event') unless audit_event

        present audit_event, with: EE::API::Entities::AuditEvent
      end
    end
  end
end
