# frozen_string_literal: true

module EE
  module GeoHelper
    STATUS_ICON_NAMES_BY_STATE = {
        synced: 'check',
        pending: 'clock-o',
        failed: 'exclamation-triangle',
        never: 'circle-o'
    }.freeze

    def self.current_node_human_status
      return s_('Geo|primary') if ::Gitlab::Geo.primary?
      return s_('Geo|secondary') if ::Gitlab::Geo.secondary?

      s_('Geo|misconfigured')
    end

    def node_vue_list_properties
      version, revision =
        if ::Gitlab::Geo.primary?
          [::Gitlab::VERSION, ::Gitlab.revision]
        else
          status = ::Gitlab::Geo.primary_node&.status

          [status&.version, status&.revision]
        end

      {
        primary_version: version.to_s,
        primary_revision: revision.to_s,
        node_actions_allowed: ::Gitlab::Database.db_read_write?.to_s,
        node_edit_allowed: ::Gitlab::Geo.license_allows?.to_s,
        geo_troubleshooting_help_path: help_page_path('administration/geo/replication/troubleshooting.md')
      }
    end

    def node_namespaces_options(namespaces)
      namespaces.map { |g| { id: g.id, text: g.full_name } }
    end

    def node_selected_namespaces_to_replicate(node)
      node.namespaces.map(&:human_name).sort.join(', ')
    end

    def node_status_icon(node)
      unless node.primary?
        status = node.enabled? ? 'unknown' : 'disabled'
        icon = status == 'healthy' ? 'check' : 'times'

        icon "#{icon} fw",
             class: "js-geo-node-icon geo-node-#{status}",
             title: status.capitalize
      end
    end

    def selective_sync_type_options_for_select(geo_node)
      options_for_select(
        [
          [s_('Geo|All projects'), ''],
          [s_('Geo|Projects in certain groups'), 'namespaces'],
          [s_('Geo|Projects in certain storage shards'), 'shards']
        ],
        geo_node.selective_sync_type
      )
    end

    def selective_sync_types_json
      options = {
        ALL: {
          label: s_('Geo|All projects'),
          value: ''
        },
        NAMESPACES: {
          label: s_('Geo|Projects in certain groups'),
          value: 'namespaces'
        },
        SHARDS: {
          label: s_('Geo|Projects in certain storage shards'),
          value: 'shards'
        }
      }

      options.to_json
    end

    def status_loading_icon
      icon "spinner spin fw", class: 'js-geo-node-loading'
    end

    def node_class(node)
      klass = []
      klass << 'js-geo-secondary-node' if node.secondary?
      klass << 'node-disabled' unless node.enabled?
      klass
    end

    def toggle_node_button(node)
      btn_class, title, data =
        if node.enabled?
          ['warning', 'Disable', { confirm: 'Disabling a node stops the sync process. Are you sure?' }]
        else
          %w[success Enable]
        end

      link_to title,
              toggle_admin_geo_node_path(node),
              method: :post,
              class: "btn btn-sm btn-#{btn_class}",
              title: title,
              data: data
    end

    def geo_registry_status(registry)
      status_type = case registry.synchronization_state
                    when :failed then
                      'text-danger-500'
                    when :synced then
                      'text-success-600'
                    end

      content_tag(:div, class: "#{status_type}") do
        icon = geo_registry_status_icon(registry)
        text = geo_registry_status_text(registry)

        [icon, text].join(' ').html_safe
      end
    end

    def geo_registry_status_icon(registry)
      icon STATUS_ICON_NAMES_BY_STATE.fetch(registry.synchronization_state, 'exclamation-triangle')
    end

    def geo_registry_status_text(registry)
      case registry.synchronization_state
      when :never
        s_('Geo|Not synced yet')
      when :failed
        s_('Geo|Failed')
      when :pending
        if registry.pending_synchronization?
          s_('Geo|Pending synchronization')
        elsif registry.pending_verification?
          s_('Geo|Pending verification')
        else
          # should never reach this state, unless we introduce new behavior
          s_('Geo|Unknown state')
        end
      when :synced
        s_('Geo|In sync')
      else
        # should never reach this state, unless we introduce new behavior
        s_('Geo|Unknown state')
      end
    end

    def remove_tracking_entry_modal_data(path)
      {
        path: path,
        method: 'delete',
        modal_attributes: {
          title: s_('Geo|Remove tracking database entry'),
          message: s_('Geo|Tracking database entry will be removed. Are you sure?'),
          okVariant: 'danger',
          okTitle: s_('Geo|Remove entry')
        }
      }
    end
  end
end
