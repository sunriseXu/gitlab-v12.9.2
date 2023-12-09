# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Packages
          class Index < QA::Page::Base
            view 'ee/app/views/projects/packages/packages/_legacy_package_list.html.haml' do
              element :package_row
              element :package_link
            end

            def click_package(name)
              click_element(:package_link, text: name)
            end

            def has_package?(name)
              has_element?(:package_link, text: name)
            end

            def has_no_package?(name)
              has_no_element?(:package_link, text: name)
            end
          end
        end
      end
    end
  end
end
