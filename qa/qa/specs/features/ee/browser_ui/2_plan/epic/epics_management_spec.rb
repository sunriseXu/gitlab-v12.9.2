# frozen_string_literal: true

module QA
  context 'Plan' do
    describe 'Epics Management' do
      before do
        Flow::Login.sign_in
      end

      it 'creates an epic', :reliable do
        epic_title = 'Epic created via GUI'
        EE::Resource::Epic.fabricate_via_browser_ui! do |epic|
          epic.title = epic_title
        end

        expect(page).to have_content(epic_title)
      end

      context 'Resources created via API' do
        let(:issue) { create_issue_resource }
        let(:epic)  { create_epic_resource(issue.project.group) }

        context 'Visit epic first' do
          before do
            epic.visit!
          end

          it 'adds/removes issue to/from epic', :reliable do
            EE::Page::Group::Epic::Show.perform do |show|
              show.add_issue_to_epic(issue.web_url)

              expect(show).to have_related_issue_item

              show.remove_issue_from_epic

              expect(show).to have_no_related_issue_item
            end
          end

          it 'comments on epic', :reliable do
            comment = 'My Epic Comment'
            EE::Page::Group::Epic::Show.perform do |show|
              show.add_comment_to_epic(comment)
            end

            expect(page).to have_content(comment)
          end

          it 'closes and reopens an epic' do
            EE::Page::Group::Epic::Show.perform(&:close_reopen_epic)

            expect(page).to have_content('Closed')

            EE::Page::Group::Epic::Show.perform(&:close_reopen_epic)

            expect(page).to have_content('Open')
          end
        end

        it 'adds/removes issue to/from epic using quick actions' do
          issue.visit!

          Page::Project::Issue::Show.perform do |show|
            show.wait_for_related_issues_to_load
            show.comment("/epic #{issue.project.group.web_url}/-/epics/#{epic.iid}")
            show.comment("/remove_epic")
          end

          epic.visit!

          expect(page).to have_content('added issue')
          expect(page).to have_content('removed issue')
        end

        def create_issue_resource
          project = Resource::Project.fabricate_via_api! do |project|
            project.name = 'project-for-issues'
            project.description = 'project for adding issues'
            project.visibility = 'private'
          end

          Resource::Issue.fabricate_via_api! do |issue|
            issue.project = project
          end
        end

        def create_epic_resource(group)
          EE::Resource::Epic.fabricate_via_api! do |epic|
            epic.group = group
            epic.title = 'Epic created via API'
          end
        end
      end
    end
  end
end
