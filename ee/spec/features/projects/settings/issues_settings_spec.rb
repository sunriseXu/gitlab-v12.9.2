# frozen_string_literal: true

require 'spec_helper'

describe 'Project settings > Issues', :js do
  let(:project) { create(:project, :public) }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)

    sign_in(user)
  end

  context 'when Issues are initially enabled' do
    context 'when Pipelines are initially enabled' do
      before do
        visit edit_project_path(project)
      end

      it 'shows the Issues settings' do
        expect(page).to have_content('Set a default template for issue descriptions.')

        within('.sharing-permissions-form') do
          find('.project-feature-controls[data-for="project[project_feature_attributes][issues_access_level]"] .project-feature-toggle').click
          click_on('Save changes')
        end

        expect(page).not_to have_content('Set a default template for issue descriptions.')
      end
    end
  end

  context 'when Issues are initially disabled' do
    before do
      project.project_feature.update_attribute('issues_access_level', ProjectFeature::DISABLED)
      visit edit_project_path(project)
    end

    it 'does not show the Issues settings' do
      expect(page).not_to have_content('Set a default template for issue descriptions.')

      within('.sharing-permissions-form') do
        find('.project-feature-controls[data-for="project[project_feature_attributes][issues_access_level]"] .project-feature-toggle').click
        click_on('Save changes')
      end

      expect(page).to have_content('Set a default template for issue descriptions.')
    end
  end

  context 'issuable default templates feature not available' do
    before do
      stub_licensed_features(issuable_default_templates: false)
    end

    it 'input to configure issue template is not shown' do
      visit edit_project_path(project)

      expect(page).not_to have_selector('#project_issues_template')
    end
  end

  context 'issuable default templates feature is available' do
    before do
      stub_licensed_features(issuable_default_templates: true)
    end

    it 'input to configure issue template is not shown' do
      visit edit_project_path(project)

      expect(page).to have_selector('#project_issues_template')
    end
  end
end
