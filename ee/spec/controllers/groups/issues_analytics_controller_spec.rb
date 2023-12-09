# frozen_string_literal: true

require 'spec_helper'

describe Groups::IssuesAnalyticsController do
  it_behaves_like 'issues analytics controller' do
    let_it_be(:user)  { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, :empty_repo, namespace: group) }
    let_it_be(:project2) { create(:project, :empty_repo, namespace: group) }
    let_it_be(:issue1) { create(:issue, project: project1, confidential: true) }
    let_it_be(:issue2) { create(:issue, project: project2, state: :closed) }

    before do
      group.add_owner(user)
      sign_in(user)
    end

    let(:params) { { group_id: group.to_param } }
  end
end
