# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module SecureReport
          def self.prepended(page)
            page.module_eval do
              view 'ee/app/assets/javascripts/security_dashboard/components/filter.vue' do
                element :filter_dropdown, ':data-qa-selector="qaSelector"' # rubocop:disable QA/ElementWithPattern
                element :filter_dropdown_content
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/security_dashboard_table_row.vue' do
                element :vulnerability_info_content
              end
            end
          end

          def filter_report_type(report)
            click_element(:filter_report_type_dropdown)
            within_element(:filter_dropdown_content) do
              click_on report
            end

            # Click the dropdown to close the modal and ensure it isn't open if this function is called again
            click_element(:filter_report_type_dropdown)
          end

          def has_vulnerability?(name)
            has_element?(:vulnerability_info_content, text: name)
          end
        end
      end
    end
  end
end
