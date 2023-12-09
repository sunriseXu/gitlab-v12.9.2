# frozen_string_literal: true

module EE
  module IssuesHelper
    extend ::Gitlab::Utils::Override

    def weight_dropdown_tag(issuable, opts = {}, &block)
      title = issuable.weight || 'Weight'
      additional_toggle_class = opts.delete(:toggle_class)
      options = {
        toggle_class: "js-weight-select #{additional_toggle_class}",
        dropdown_class: 'dropdown-menu-selectable dropdown-menu-weight',
        title: 'Select weight',
        placeholder: 'Search weight',
        data: {
          field_name: "#{issuable.class.model_name.param_key}[weight]",
          default_label: 'Weight'
        }
      }.deep_merge(opts)

      dropdown_tag(title, options: options) do
        capture(&block)
      end
    end

    def weight_dropdown_label(weight)
      if Issue.weight_options.include?(weight)
        weight
      else
        h(weight.presence || 'Weight')
      end
    end

    override :issue_closed_link
    def issue_closed_link(issue, current_user, css_class: '')
      if issue.promoted? && can?(current_user, :read_epic, issue.promoted_to_epic)
        link_to(s_('IssuableStatus|promoted'), issue.promoted_to_epic, class: css_class)
      else
        super
      end
    end
  end
end
