# frozen_string_literal: true

module QA::EE
  module Page::Project
    module Pipeline
      module Show
        include Page::Component::LicenseManagement
        include Page::Component::SecureReport

        def self.prepended(page)
          page.module_eval do
            view 'ee/app/views/projects/pipelines/_tabs_holder.html.haml' do
              element :security_tab
              element :licenses_tab
              element :licenses_counter
            end
          end
        end

        def click_on_security
          click_element(:security_tab)
        end

        def click_on_licenses
          click_element(:licenses_tab)
        end

        def has_license_count_of?(count)
          find_element(:licenses_counter).has_content?(count)
        end
      end
    end
  end
end
