# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Settings
          class Integration < QA::Page::Base
            include QA::Page::Settings::Common

            view 'ee/app/views/admin/application_settings/_elasticsearch_form.html.haml' do
              element :elasticsearch_tab
            end

            def expand_elasticsearch(&block)
              expand_section(:elasticsearch_tab) do
                Component::Elasticsearch.perform(&block)
              end
            end
          end
        end
      end
    end
  end
end
