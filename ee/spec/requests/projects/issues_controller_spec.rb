# frozen_string_literal: true

require 'spec_helper'

describe Projects::IssuesController do
  let_it_be(:issue) { create(:issue) }
  let_it_be(:project) { issue.project }
  let_it_be(:user) { issue.author }
  let_it_be(:blocking_issue) { create(:issue, project: project) }
  let_it_be(:blocked_by_issue) { create(:issue, project: project) }

  before do
    login_as(user)
  end

  describe 'GET #show' do
    def get_show
      get project_issue_path(project, issue)
    end

    context 'with blocking issues' do
      before do
        stub_feature_flags(prevent_closing_blocked_issues: true)

        get_show # Warm the cache
      end

      it 'does not cause extra queries when multiple blocking issues are present' do
        create(:issue_link, source: blocking_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)

        control = ActiveRecord::QueryRecorder.new { get_show }

        other_project_issue = create(:issue)
        other_project_issue.project.add_developer(user)
        create(:issue_link, source: issue, target: other_project_issue, link_type: IssueLink::TYPE_IS_BLOCKED_BY)

        expect { get_show }.not_to exceed_query_limit(control)
      end
    end
  end
end
