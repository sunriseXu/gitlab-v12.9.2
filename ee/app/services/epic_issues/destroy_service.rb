# frozen_string_literal: true

module EpicIssues
  class DestroyService < IssuableLinks::DestroyService
    def execute
      result = super
      Epics::UpdateDatesService.new([link.epic]).execute

      result
    end

    private

    def source
      @source ||= link.epic
    end

    def target
      @target ||= link.issue
    end

    def permission_to_remove_relation?
      can?(current_user, :admin_epic_issue, target) && can?(current_user, :admin_epic, source)
    end

    def create_notes
      SystemNoteService.epic_issue(source, target, current_user, :removed)
      SystemNoteService.issue_on_epic(target, source, current_user, :removed)
    end
  end
end
