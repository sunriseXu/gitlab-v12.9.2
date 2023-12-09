# frozen_string_literal: true

module EE
  module LabelsHelper
    extend ActiveSupport::Concern

    prepended do
      singleton_class.prepend self
    end

    def render_colored_label(label, suffix: '')
      return super unless label.scoped_label?

      render_label_text(
        label.scoped_label_key,
        css_class: text_color_class_for_bg(label.color),
        bg_color: label.color
      ) + render_label_text(
        label.scoped_label_value,
        css_class: ('gl-label-text-dark' if light_color?(label.color)),
        suffix: suffix
      )
    end

    def wrap_label_html(label_html, small:, label:)
      return super unless label.scoped_label?

      wrapper_classes = %w(gl-label gl-label-scoped)
      wrapper_classes << 'gl-label-sm' if small

      <<~HTML.chomp.html_safe
        <span class="d-inline-block position-relative scoped-label-wrapper">
          <span class="#{wrapper_classes.join(' ')}" style="color: #{label.color}">#{label_html + scoped_labels_doc_link}</span>
        </span>
      HTML
    end

    def label_tooltip_title(label)
      tooltip = super
      tooltip = %(<span class='font-weight-bold scoped-label-tooltip-title'>Scoped label</span><br />#{tooltip}) if label.scoped_label?

      tooltip
    end

    def label_dropdown_data(edit_context, opts = {})
      scoped_labels_fields = {
        scoped_labels: edit_context&.feature_available?(:scoped_labels)&.to_s,
        scoped_labels_documentation_link: help_page_path('user/project/labels.md', anchor: 'scoped-labels-premium')
      }

      return super.merge(scoped_labels_fields) unless edit_context.is_a?(Group)

      {
        toggle: "dropdown",
        field_name: opts[:field_name] || "label_name[]",
        show_no: "true",
        show_any: "true",
        group_id: edit_context&.try(:id)
      }.merge(scoped_labels_fields, opts)
    end

    def sidebar_label_dropdown_data(issuable_type, issuable_sidebar)
      super.merge({
        scoped_labels: issuable_sidebar[:scoped_labels_available].to_s
      })
    end

    def issuable_types
      return super unless @group&.feature_available?(:epics)

      super + ['epics']
    end

    private

    def scoped_labels_doc_link
      help_url = ::Gitlab::Routing.url_helpers.help_page_path('user/project/labels.md', anchor: 'scoped-labels-premium')

      %(<a href="#{help_url}" class="gl-link gl-label-icon" target="_blank" rel="noopener"><i class="fa fa-question-circle"></i></a>).html_safe
    end
  end
end
