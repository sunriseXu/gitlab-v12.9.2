# frozen_string_literal: true

module EE
  module API
    module Search
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          ELASTICSEARCH_SCOPES = %w(wiki_blobs blobs commits).freeze

          override :verify_search_scope!
          def verify_search_scope!(resource:)
            if ELASTICSEARCH_SCOPES.include?(params[:scope]) && !use_elasticsearch?(resource)
              render_api_error!({ error: 'Scope not supported without Elasticsearch!' }, 400)
            end
          end

          def use_elasticsearch?(resource)
            ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: resource)
          end
        end
      end
    end
  end
end
