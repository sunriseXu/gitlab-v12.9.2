# frozen_string_literal: true

module API
  module Helpers
    module Packages
      module DependencyProxyHelpers
        REGISTRY_BASE_URLS = {
          npm: 'https://registry.npmjs.org/'
        }.freeze

        def redirect_registry_request(forward_to_registry, package_type, options)
          if redirect_registry_request_available? && forward_to_registry
            redirect(registry_url(package_type, options))
          else
            yield
          end
        end

        def registry_url(package_type, options)
          base_url = REGISTRY_BASE_URLS[package_type]

          raise ArgumentError, "Can't build registry_url for package_type #{package_type}" unless base_url

          case package_type
          when :npm
            "#{base_url}#{options[:package_name]}"
          end
        end

        def redirect_registry_request_available?
          Feature.enabled?(:forward_npm_package_registry_requests, default_enabled: true) &&
            ::Gitlab::CurrentSettings.current_application_settings.npm_package_requests_forwarding
        end
      end
    end
  end
end
