# frozen_string_literal: true

module QA
  context 'Manage', :group_saml, :orchestrated do
    describe 'Group SAML SSO - Enforced SSO' do
      include Support::Api

      before(:all) do
        Support::Retrier.retry_on_exception do
          Flow::Saml.remove_saml_idp_service(@saml_idp_service) if @saml_idp_service

          @group = Resource::Sandbox.fabricate_via_api! do |sandbox_group|
            sandbox_group.path = "saml_sso_group_#{SecureRandom.hex(8)}"
          end

          @developer_user = Resource::User.fabricate_via_api!

          @group.add_member(@developer_user)

          @saml_idp_service = Flow::Saml.run_saml_idp_service(@group.path)

          @managed_group_url = setup_and_enable_enforce_sso
        end
      end

      before do
        Flow::Saml.logout_from_idp(@saml_idp_service)

        page.visit Runtime::Scenario.gitlab_address
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
      end

      context 'Access', quarantine: { issue: 'https://gitlab.com/gitlab-org/gitlab/issues/205455', type: :flaky } do
        let(:project) do
          Resource::Project.fabricate! do |project|
            project.name = 'project-in-saml-enforced-group-for-access-test'
            project.description = 'project in SAML enforced group for access test'
            project.group = @group
            project.initialize_with_readme = true
            project.visibility = 'private'
          end
        end

        let(:sub_group) do
          Resource::Group.fabricate_via_api! do |group|
            group.sandbox = @group
            group.path = "saml-sub-group"
          end
        end

        let(:sub_group_project) do
          Resource::Project.fabricate! do |project|
            project.name = 'sub-group-project-in-saml-enforced-group-for-access-test'
            project.description = 'Sub Group project in SAML enforced group for access test'
            project.group = sub_group
            project.initialize_with_readme = true
            project.visibility = 'private'
          end
        end

        shared_examples 'user access' do
          it 'is not allowed without SSO' do
            Page::Main::Login.perform do |login|
              login.sign_in_using_credentials(user: user)
            end

            expected_single_signon_text = 'group allows you to sign in with your Single Sign-On Account'

            @group.visit!

            expect(page).to have_content(expected_single_signon_text)

            sub_group.visit!

            expect(page).to have_content(expected_single_signon_text)

            project.visit!

            expect(page).to have_content(expected_single_signon_text)

            sub_group_project.visit!

            expect(page).to have_content(expected_single_signon_text)
          end
        end

        before(:all) do
          @owner_user = Resource::User.fabricate_via_api!

          @group.add_member(@owner_user, Resource::Members::AccessLevel::OWNER)
        end

        after(:all) do
          @group.remove_member(@owner_user) if @owner_user
        end

        it_behaves_like 'user access' do
          let(:user) { @developer_user }
        end
        it_behaves_like 'user access' do
          let(:user) { @owner_user }
        end
      end

      it 'user clones and pushes to project within a group using Git HTTP' do
        Flow::Login.sign_in

        @project = Resource::Project.fabricate! do |project|
          project.name = 'project-in-saml-enforced-group'
          project.description = 'project in SAML enforced group for git clone test'
          project.group = @group
          project.initialize_with_readme = true
        end

        @project.visit!

        expect do
          Resource::Repository::ProjectPush.fabricate! do |project_push|
            project_push.project = @project
            project_push.branch_name = "new_branch"
            project_push.user = @developer_user
          end
        end.not_to raise_error
      end

      after(:all) do
        page.visit Runtime::Scenario.gitlab_address
        %w[enforced_sso enforced_sso_requires_session].each do |flag|
          Runtime::Feature.remove(flag)
        end

        @group.remove_via_api!

        Page::Main::Menu.perform(&:sign_out_if_signed_in)

        Flow::Saml.remove_saml_idp_service(@saml_idp_service)
      end
    end

    def setup_and_enable_enforce_sso
      %w[enforced_sso enforced_sso_requires_session].each do |flag|
        Runtime::Feature.enable_and_verify(flag)
      end

      page.visit Runtime::Scenario.gitlab_address
      Page::Main::Login.perform(&:sign_in_using_credentials) unless Page::Main::Menu.perform(&:signed_in?)

      Support::Retrier.retry_on_exception do
        Flow::Saml.visit_saml_sso_settings(@group)
        ensure_enforced_sso_button_shown

        managed_group_url = EE::Page::Group::Settings::SamlSSO.perform do |saml_sso|
          saml_sso.enforce_sso

          saml_sso.set_id_provider_sso_url(@saml_idp_service.idp_sso_url)
          saml_sso.set_cert_fingerprint(@saml_idp_service.idp_certificate_fingerprint)

          saml_sso.click_save_changes

          saml_sso.user_login_url_link_text
        end

        Flow::Saml.visit_saml_sso_settings(@group, direct: true)
        ensure_enforced_sso_button_shown

        unless EE::Page::Group::Settings::SamlSSO.perform(&:enforce_sso_enabled?)
          QA::Runtime::Logger.debug "Enforced SSO not setup correctly. About to raise failure."
          QA::Runtime::Logger.debug Capybara::Screenshot.screenshot_and_save_page
          QA::Runtime::Logger.debug Runtime::Feature.get_features

          raise "Enforced SSO not setup correctly"
        end

        managed_group_url
      end
    end

    def ensure_enforced_sso_button_shown
      # Sometimes, the toggle button for SAML SSO does not appear and only appears after a refresh
      # This issue can only be reproduced manually if you are too quick to go to the group setting page
      # after enabling the feature flags.
      Support::Retrier.retry_until(sleep_interval: 1, raise_on_failure: true) do
        condition_met = EE::Page::Group::Settings::SamlSSO.perform(&:has_enforced_sso_button?)
        page.refresh unless condition_met
        condition_met
      end
    end
  end
end
