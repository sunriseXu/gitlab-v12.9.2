# frozen_string_literal: true

module QA
  context 'Geo', :orchestrated, :geo do
    describe 'GitLab SSH push' do
      let(:file_name) { 'README.md' }

      context 'regular git commit' do
        it "is replicated to the secondary" do
          key_title = "key for ssh tests #{Time.now.to_f}"
          file_content = 'This is a Geo project! Commit from primary.'
          project = nil
          key = nil

          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            # Create a new SSH key for the user
            key = Resource::SSHKey.fabricate_via_api! do |resource|
              resource.title = key_title
            end

            # Create a new Project
            project = Resource::Project.fabricate_via_api! do |project|
              project.name = 'geo-project'
              project.description = 'Geo test project'
            end

            # Perform a git push over SSH directly to the primary
            Resource::Repository::ProjectPush.fabricate! do |push|
              push.ssh_key = key
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end.project.visit!

            # Validate git push worked and file exists with content
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end

          QA::Runtime::Logger.debug('Visiting the secondary geo node')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            EE::Page::Main::Banner.perform do |banner|
              expect(banner).to have_secondary_read_only_banner
            end

            # Ensure the SSH key has replicated
            Page::Main::Menu.act { click_settings_link }
            Page::Profile::Menu.act { click_ssh_keys }

            expect(page).to have_content(key_title)
            expect(page).to have_content(key.md5_fingerprint)

            # Ensure project has replicated
            Page::Main::Menu.perform { |menu| menu.go_to_projects }
            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            # Validate the content has been sync'd from the primary
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication_with(file_content)

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end
        end
      end

      context 'git-lfs commit' do
        it "is replicated to the secondary" do
          key_title = "key for ssh tests #{Time.now.to_f}"
          file_content = 'The rendered file could not be displayed because it is stored in LFS.'
          project = nil
          key = nil

          QA::Flow::Login.while_signed_in(address: :geo_primary) do
            # Create a new SSH key for the user
            key = Resource::SSHKey.fabricate_via_api! do |resource|
              resource.title = key_title
            end

            # Create a new Project
            project = Resource::Project.fabricate_via_api! do |project|
              project.name = 'geo-project'
              project.description = 'Geo test project'
            end

            # Perform a git push over SSH directly to the primary
            push = Resource::Repository::ProjectPush.fabricate! do |push|
              push.use_lfs = true
              push.ssh_key = key
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end

            expect(push.output).to match(/Locking support detected on remote/)

            # Validate git push worked and file exists with content
            push.project.visit!
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end

          QA::Runtime::Logger.debug('Visiting the secondary geo node')

          QA::Flow::Login.while_signed_in(address: :geo_secondary) do
            EE::Page::Main::Banner.perform do |banner|
              expect(banner).to have_secondary_read_only_banner
            end

            # Ensure the SSH key has replicated
            Page::Main::Menu.act { click_settings_link }
            Page::Profile::Menu.act { click_ssh_keys }

            expect(page).to have_content(key_title)
            expect(page).to have_content(key.md5_fingerprint)

            # Ensure project has replicated
            Page::Main::Menu.perform { |menu| menu.go_to_projects }
            Page::Dashboard::Projects.perform do |dashboard|
              dashboard.wait_for_project_replication(project.name)
              dashboard.go_to_project(project.name)
            end

            # Validate the content has been sync'd from the primary
            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication_with(file_name)

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end
        end
      end
    end
  end
end
