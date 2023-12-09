# frozen_string_literal: true

module QA
  context 'Create' do
    # Use Admin credentials as a workaround for a permissions bug
    # See https://gitlab.com/gitlab-org/gitlab/issues/13769
    describe 'Pull mirror a repository over HTTP', :requires_admin do
      it 'configures and syncs a (pull) mirrored repository with password auth' do
        Flow::Login.sign_in_as_admin

        source = Resource::Repository::ProjectPush.fabricate! do |project_push|
          project_push.project_name = 'pull-mirror-source-project'
          project_push.file_name = 'README.md'
          project_push.file_content = '# This is a pull mirroring test project'
          project_push.commit_message = 'Add README.md'
        end
        source_project_uri = source.project.repository_http_location.uri
        source_project_uri.user = CGI.escape(Runtime::User.admin_username)

        target_project = Resource::Project.fabricate_via_api! do |project|
          project.name = 'pull-mirror-target-project'
        end
        target_project.visit!

        Page::Project::Menu.perform(&:go_to_repository_settings)
        Page::Project::Settings::Repository.perform do |settings|
          settings.expand_mirroring_repositories do |mirror_settings|
            # Configure the target project to pull from the source project
            mirror_settings.repository_url = source_project_uri
            mirror_settings.mirror_direction = 'Pull'
            mirror_settings.authentication_method = 'Password'
            mirror_settings.password = Runtime::User.admin_password
            mirror_settings.mirror_repository
            mirror_settings.update source_project_uri
          end
        end

        # Check that the target project has the commit from the source
        target_project.visit!
        expect(page).to have_content("README.md")
        expect(page).to have_content("This is a pull mirroring test project")
        expect(page).to have_content("Mirrored from #{masked_url(source_project_uri)}")
      end

      def masked_url(url)
        url.password = '*****'
        url.user = '*****'
        url
      end
    end
  end
end
