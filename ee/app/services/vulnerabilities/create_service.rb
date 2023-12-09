# frozen_string_literal: true

module Vulnerabilities
  class CreateService
    include Gitlab::Allowable

    def initialize(project, author, finding_id:)
      @project = project
      @author = author
      @finding_id = finding_id
    end

    def execute
      raise Gitlab::Access::AccessDeniedError unless can?(@author, :create_vulnerability, @project)

      vulnerability = Vulnerability.new

      Vulnerabilities::Occurrence.transaction(requires_new: true) do
        # we're using `lock` instead of `with_lock` to avoid extra call to `find` under the hood
        finding = @project.vulnerability_findings.lock_for_confirmation!(@finding_id)

        save_vulnerability(vulnerability, finding)
      rescue ActiveRecord::RecordNotFound
        vulnerability.errors.add(:base, _('finding is not found or is already attached to a vulnerability'))
        raise ActiveRecord::Rollback
      end

      vulnerability
    end

    private

    def save_vulnerability(vulnerability, finding)
      vulnerability.assign_attributes(
        author: @author,
        project: @project,
        title: finding.name,
        state: Vulnerability.states[:detected],
        severity: finding.severity,
        severity_overridden: false,
        confidence: finding.confidence,
        confidence_overridden: false,
        report_type: finding.report_type
      )
      vulnerability.save && vulnerability.findings << finding
    end
  end
end
