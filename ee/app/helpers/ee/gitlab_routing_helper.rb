# frozen_string_literal: true

module EE
  module GitlabRoutingHelper
    include ::ProjectsHelper
    include ::ApplicationSettingsHelper
    include ::API::Helpers::RelatedResourcesHelpers

    def geo_primary_web_url(project_or_wiki)
      File.join(::Gitlab::Geo.primary_node.url, project_or_wiki.full_path)
    end

    def geo_primary_ssh_url_to_repo(project_or_wiki)
      "#{::Gitlab::Geo.primary_node.clone_url_prefix}#{project_or_wiki.full_path}.git"
    end

    def geo_primary_http_url_to_repo(project_or_wiki)
      geo_primary_web_url(project_or_wiki) + '.git'
    end

    def geo_primary_default_url_to_repo(project_or_wiki)
      case default_clone_protocol
      when 'ssh'
        geo_primary_ssh_url_to_repo(project_or_wiki)
      else
        geo_primary_http_url_to_repo(project_or_wiki)
      end
    end

    def epic_path(entity, *args)
      group_epic_path(entity.group, entity, *args)
    end

    def license_management_api_url(project)
      expose_path(api_v4_projects_managed_licenses_path(id: project.id))
    end

    def license_management_settings_path(project)
      project_settings_ci_cd_path(project, anchor: 'js-license-management')
    end

    def vulnerability_path(entity, *args)
      project_security_vulnerability_path(entity.project, entity, *args)
    end

    def self.url_helper(route_name)
      define_method("#{route_name}_url") do |*args|
        path = public_send(:"#{route_name}_path", *args) # rubocop:disable GitlabSecurity/PublicSend
        options = Rails.application.routes.default_url_options.merge(path: path)
        ActionDispatch::Http::URL.full_url_for(options)
      end
    end

    url_helper :user_group_saml_omniauth_metadata
    def user_group_saml_omniauth_metadata_path(group)
      params = { group_path: group.path, token: group.saml_discovery_token }
      path = '/users/auth/group_saml/metadata'

      ActionDispatch::Http::URL.path_for(path: path, params: params)
    end
  end
end
