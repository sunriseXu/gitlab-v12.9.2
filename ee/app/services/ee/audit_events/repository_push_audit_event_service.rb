# frozen_string_literal: true

module EE
  module AuditEvents
    class RepositoryPushAuditEventService < ::AuditEventService
      def initialize(author, project, target_ref, from, to)
        super(author, project, {
          updated_ref: ::Gitlab::Git.ref_name(target_ref),
          author_name: author.name,
          from: Commit.truncate_sha(from),
          to: Commit.truncate_sha(to),
          target_details: project.full_path
        })
      end

      def attributes
        base_payload.merge(type: SecurityEvent.to_s,
                           created_at: DateTime.now,
                           updated_at: DateTime.now,
                           details: @details.to_yaml)
      end

      def enabled?
        super && @entity.push_audit_events_enabled?
      end
    end
  end
end
