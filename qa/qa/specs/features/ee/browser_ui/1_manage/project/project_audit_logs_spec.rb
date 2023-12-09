# frozen_string_literal: true

module QA
  context 'Manage' do
    shared_examples 'project audit event logs' do |expected_events|
      it 'logs audit events for UI operations' do
        Page::Project::Menu.perform(&:go_to_audit_events_settings)
        expected_events.each do |expected_event|
          expect(page).to have_text(expected_event)
        end
      end
    end

    describe 'Project audit logs' do
      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'awesome-project'
          project.initialize_with_readme = true
        end
      end

      before do
        sign_in
      end

      let(:user) { Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1) }

      context "Add project" do
        before do
          Resource::Project.fabricate_via_browser_ui! do |project|
            project.name = 'audit-add-project-via-ui'
            project.initialize_with_readme = true
          end.visit!
        end
        it_behaves_like 'project audit event logs', ["Add project"]
      end

      context "Add user access as guest" do
        before do
          project.visit!

          Page::Project::Menu.perform(&:go_to_members_settings)
          Page::Project::Settings::Members.perform do |members|
            members.add_member(user.username)
          end
        end

        it_behaves_like 'project audit event logs', ["Add user access as guest"]
      end

      context "Add deploy key", quarantine: 'https://gitlab.com/gitlab-org/gitlab/issues/208761' do
        before do
          key = Runtime::Key::RSA.new
          deploy_key_title = 'deploy key title'
          deploy_key_value = key.public_key

          Resource::DeployKey.fabricate_via_browser_ui! do |resource|
            resource.project = project
            resource.title = deploy_key_title
            resource.key = deploy_key_value
          end
        end

        it_behaves_like 'project audit event logs', ["Add deploy key"]
      end

      context "Change visibility" do
        before do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            # Change visibility from public to internal
            settings.expand_visibility_project_features_permissions do |page|
              page.set_project_visibility "Internal"
            end
          end
        end

        it_behaves_like 'project audit event logs', ["Change visibility from public to internal"]
      end

      context "Export file download", quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/issues/202249', type: :bug } do
        before do
          project.visit!

          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_advanced_settings(&:click_export_project_link)
            expect(page).to have_text("Project export started")

            Page::Project::Menu.perform(&:go_to_general_settings)
            settings.expand_advanced_settings(&:click_download_export_link)
          end
        end

        it_behaves_like 'project audit event logs', ["Export file download started"]
      end

      context "Project archive and unarchive" do
        before do
          project.visit!

          # Project archive
          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_advanced_settings(&:archive_project)
          end

          # Project unarchived
          Page::Project::Menu.perform(&:go_to_general_settings)
          Page::Project::Settings::Main.perform do |settings|
            settings.expand_advanced_settings(&:unarchive_project)
          end
        end

        it_behaves_like 'project audit event logs', ["Project archived", "Project unarchived"]
      end

      def sign_in
        unless Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }
          Flow::Login.sign_in
        end
      end
    end
  end
end
