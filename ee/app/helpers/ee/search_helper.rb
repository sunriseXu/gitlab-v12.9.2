# frozen_string_literal: true
module EE
  module SearchHelper
    extend ::Gitlab::Utils::Override

    SWITCH_TO_BASIC_SEARCHABLE_TABS = %w[projects issues merge_requests milestones users].freeze

    override :search_filter_input_options
    def search_filter_input_options(type)
      options = super
      options[:data][:'multiple-assignees'] = 'true' if search_multiple_assignees?(type)

      if @project&.group
        options[:data]['epics-endpoint'] = group_epics_path(@project.group)
      elsif @group.present?
        options[:data]['epics-endpoint'] = group_epics_path(@group)
      end

      options
    end

    override :search_blob_title
    def search_blob_title(project, path)
      if @project
        path
      else
        (project.full_name + ': ' + content_tag(:i, path)).html_safe
      end
    end

    # This is a special case for snippet searches in .com.
    # The scope used to gather the snippets is too wide and
    # we have to process a lot of them, what leads to time outs.
    # We're reducing the scope only in .com because the current
    # one is still valid in smaller installations.
    # https://gitlab.com/gitlab-org/gitlab/issues/26123
    override :search_entries_info_template
    def search_entries_info_template(collection)
      return super unless gitlab_com_snippet_db_search?

      if collection.total_pages > 1
        s_("SearchResults|Showing %{from} - %{to} of %{count} %{scope} for%{term_element} in your personal and project snippets").html_safe
      else
        s_("SearchResults|Showing %{count} %{scope} for%{term_element} in your personal and project snippets").html_safe
      end
    end

    def revert_to_basic_search_filter_url
      search_params = params
        .permit(::SearchHelper::SEARCH_PERMITTED_PARAMS)
        .merge(basic_search: true)

      search_path(search_params)
    end

    def show_switch_to_basic_search?(search_service)
      return false unless ::Feature.enabled?(:switch_to_basic_search, default_enabled: false)
      return false unless search_service.use_elasticsearch?

      return true if @project

      search_service.scope.in?(SWITCH_TO_BASIC_SEARCHABLE_TABS)
    end

    private

    def search_multiple_assignees?(type)
      context = @project.presence || @group.presence || :dashboard

      type == :issues && (context == :dashboard ||
        context.feature_available?(:multiple_issue_assignees))
    end

    def gitlab_com_snippet_db_search?
      @current_user &&
        @show_snippets &&
        ::Gitlab.com? &&
        ::Feature.enabled?(:restricted_snippet_scope_search, default_enabled: true) &&
        ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: nil)
    end
  end
end
