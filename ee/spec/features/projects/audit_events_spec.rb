# frozen_string_literal: true

require 'spec_helper'

describe 'Projects > Audit Events', :js do
  let(:user) { create(:user) }
  let(:pete) { create(:user, name: 'Pete') }
  let(:project) { create(:project, :repository, namespace: user.namespace) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  context 'unlicensed' do
    before do
      stub_licensed_features(audit_events: false)
    end

    it 'returns 404' do
      reqs = inspect_requests do
        visit project_audit_events_path(project)
      end

      expect(reqs.first.status_code).to eq(404)
    end

    it 'does not have Audit Events button in head nav bar' do
      visit edit_project_path(project)

      expect(page).not_to have_link('Audit Events')
    end
  end

  context 'unlicensed but we show promotions' do
    before do
      stub_licensed_features(audit_events: false)
      allow(License).to receive(:current).and_return(nil)
      stub_application_setting(check_namespace_plan: false)
      allow(LicenseHelper).to receive(:show_promotions?).and_return(true)
    end

    it 'returns 200' do
      reqs = inspect_requests do
        visit project_audit_events_path(project)
      end

      expect(reqs.first.status_code).to eq(200)
    end

    it 'does not have Audit Events button in head nav bar' do
      visit edit_project_path(project)

      expect(page).to have_link('Audit Events')
    end

    it 'does not have Project Audit Events in the header' do
      visit project_audit_events_path(project)

      expect(page).not_to have_content('Project Audit Events')
    end
  end

  it 'has Audit Events button in head nav bar' do
    visit edit_project_path(project)

    expect(page).to have_link('Audit Events')
  end

  it 'has Project Audit Events in the header' do
    visit project_audit_events_path(project)

    expect(page).to have_content('Project Audit Events')
  end

  describe 'adding an SSH key' do
    it "appears in the project's audit events" do
      stub_licensed_features(audit_events: true)

      visit new_project_deploy_key_path(project)

      fill_in 'deploy_key_title', with: 'laptop'
      fill_in 'deploy_key_key', with: 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzrEJUIR6Y03TCE9rIJ+GqTBvgb8t1jI9h5UBzCLuK4VawOmkLornPqLDrGbm6tcwM/wBrrLvVOqi2HwmkKEIecVO0a64A4rIYScVsXIniHRS6w5twyn1MD3sIbN+socBDcaldECQa2u1dI3tnNVcs8wi77fiRe7RSxePsJceGoheRQgC8AZ510UdIlO+9rjIHUdVN7LLyz512auAfYsgx1OfablkQ/XJcdEwDNgi9imI6nAXhmoKUm1IPLT2yKajTIC64AjLOnE0YyCh6+7RFMpiMyu1qiOCpdjYwTgBRiciNRZCH8xIedyCoAmiUgkUT40XYHwLuwiPJICpkAzp7Q== user@laptop'

      click_button 'Add key'

      visit project_audit_events_path(project)

      expect(page).to have_content('Add deploy key')

      visit project_deploy_keys_path(project)

      accept_confirm do
        find('.ic-remove').click
      end

      visit project_audit_events_path(project)

      wait_for('Audit event background creation job is done', polling_interval: 0.5, reload: true) do
        page.has_content?('Remove deploy key', wait: 0)
      end
    end
  end

  describe 'changing a user access level' do
    before do
      project.add_developer(pete)
    end

    it "appears in the project's audit events" do
      visit project_settings_members_path(project)

      project_member = project.project_member(pete)

      page.within "#project_member_#{project_member.id}" do
        click_button 'Developer'
        click_link 'Maintainer'
      end

      find(:link, text: 'Settings').click

      click_link 'Audit Events'

      page.within('#audits') do
        expect(page).to have_content 'Change access level from developer to maintainer'
        expect(page).to have_content(project.owner.name)
        expect(page).to have_content('Pete')
      end
    end
  end

  describe 'changing merge request approval permission for authors and reviewers' do
    before do
      project.add_developer(pete)
    end

    it "appears in the project's audit events" do
      visit edit_project_path(project)

      page.within('#js-merge-request-approval-settings') do
        uncheck 'project_merge_requests_author_approval'
        check 'project_merge_requests_disable_committers_approval'
        click_button 'Save changes'
      end

      wait_for('Save is completed') do
        page.has_content?('was successfully updated', wait: 0)
      end

      page.within('.qa-project-sidebar') do
        find(:link, text: 'Settings').click
        click_link 'Audit Events'
      end

      wait_for_all_requests

      page.within('#audits') do
        expect(page).to have_content(project.owner.name)
        expect(page).to have_content('Change prevent merge request approval from authors')
        expect(page).to have_content('Change prevent merge request approval from reviewers')
        expect(page).to have_content(project.name)
      end
    end
  end

  it_behaves_like 'audit event contains custom message' do
    let(:audit_events_url) { project_audit_events_path(project) }
  end

  describe 'filter by date', js: false do
    let!(:audit_event_1) { create(:project_audit_event, entity_type: 'Project', entity_id: project.id, created_at: 5.days.ago) }
    let!(:audit_event_2) { create(:project_audit_event, entity_type: 'Project', entity_id: project.id, created_at: 3.days.ago) }
    let!(:audit_event_3) { create(:project_audit_event, entity_type: 'Project', entity_id: project.id, created_at: 1.day.ago) }

    before do
      visit project_audit_events_path(project)
    end

    it_behaves_like 'audit events filter'
  end
end
