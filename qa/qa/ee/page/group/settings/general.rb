# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          module General
            prepend ::QA::Page::Component::Select2
            prepend ::QA::Page::Settings::Common

            def self.included(base)
              base.class_eval do
                view 'ee/app/views/groups/_custom_project_templates_setting.html.haml' do
                  element :custom_project_template_select
                  element :custom_project_templates
                  element :save_changes_button
                end

                view 'ee/app/views/groups/settings/_ip_restriction.html.haml' do
                  element :ip_restriction_field
                end

                view 'ee/app/views/groups/_member_lock_setting.html.haml' do
                  element :membership_lock_checkbox
                end

                view 'ee/app/views/shared/_repository_size_limit_setting.html.haml' do
                  element :repository_size_limit_field
                end

                view 'ee/app/views/groups/_templates_setting.html.haml' do
                  element :file_template_repository_dropdown
                  element :file_template_repositories
                  element :save_changes_button
                end
              end
            end

            def current_custom_project_template
              expand_section(:custom_project_templates)

              within_element(:custom_project_template_select) do
                current_selection
              end
            end

            def choose_custom_project_template(path)
              expand_section(:custom_project_templates)

              within_element(:custom_project_template_select) do
                clear_current_selection_if_present
              end
              click_element :custom_project_template_select
              search_and_select(path)
              click_element :save_changes_button
            end

            def set_ip_address_restriction(ip_address)
              expand_section(:permission_lfs_2fa_section)
              find_element(:ip_restriction_field).send_keys([:command, 'a'], :backspace)
              find_element(:ip_restriction_field).set ip_address
              click_element :save_permissions_changes_button
            end

            def set_membership_lock_enabled
              expand_section :permission_lfs_2fa_section
              check_element :membership_lock_checkbox
              click_element :save_permissions_changes_button
            end

            def set_membership_lock_disabled
              expand_section :permission_lfs_2fa_section
              uncheck_element :membership_lock_checkbox
              click_element :save_permissions_changes_button
            end

            def set_repository_size_limit(limit)
              find_element(:repository_size_limit_field).set limit
            end

            def current_file_template_repository
              expand_section(:file_template_repositories)

              within_element(:file_template_repository_dropdown) do
                current_selection
              end
            end

            def choose_file_template_repository(path)
              expand_section(:file_template_repositories)

              within_element(:file_template_repository_dropdown) do
                clear_current_selection_if_present
              end
              click_element :file_template_repository_dropdown
              search_and_select(path)
              click_element :save_changes_button
            end
          end
        end
      end
    end
  end
end
