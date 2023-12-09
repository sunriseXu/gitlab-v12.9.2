# frozen_string_literal: true

require 'spec_helper'

describe 'Slack application' do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:role) { :developer }
  let(:service) { create(:gitlab_slack_application_service, project: project) }
  let(:slack_application_form_path) { edit_project_service_path(project, service) }

  before do
    gitlab_sign_in(user)
    project.add_maintainer(user)

    create(:slack_integration, service: service)

    allow(Gitlab).to receive(:com?).and_return(true)
  end

  it 'I can edit slack integration' do
    visit slack_application_form_path

    within '.js-integration-settings-form' do
      click_link 'Edit'
    end

    fill_in 'slack_integration_alias', with: 'alias-edited'
    click_button 'Save changes'

    expect(page).to have_content('The project alias was updated successfully')

    within '.js-integration-settings-form' do
      expect(page).to have_content('alias-edited')
    end
  end
end
