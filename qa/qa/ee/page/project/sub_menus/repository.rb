# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module SubMenus
          module Repository
            def self.included(page)
              page.class_eval do
                view 'ee/app/views/projects/sidebar/_repository_locked_files.html.haml' do
                  element :path_locks_link
                end
              end
            end

            def go_to_repository_locked_files
              hover_repository do
                within_submenu do
                  click_element :path_locks_link
                end
              end
            end
          end
        end
      end
    end
  end
end
