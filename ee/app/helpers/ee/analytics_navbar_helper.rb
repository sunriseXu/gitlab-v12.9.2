# frozen_string_literal: true

module EE
  module AnalyticsNavbarHelper
    extend ::Gitlab::Utils::Override

    override :project_analytics_navbar_links
    def project_analytics_navbar_links(project, current_user)
      super + [
        insights_navbar_link(project, current_user),
        code_review_analytics_navbar_link(project, current_user),
        project_issues_analytics_navbar_link(project, current_user)
      ].compact
    end

    override :group_analytics_navbar_links
    def group_analytics_navbar_links(group, current_user)
      super + [
        contribution_analytics_navbar_link(group, current_user),
        group_insights_navbar_link(group, current_user),
        issues_analytics_navbar_link(group, current_user),
        productivity_analytics_navbar_link(group, current_user),
        group_cycle_analytics_navbar_link(group, current_user)
      ].compact
    end

    private

    def project_issues_analytics_navbar_link(project, current_user)
      return unless ::Feature.enabled?(:project_level_issues_analytics, project, default_enabled: true)
      return unless project_nav_tab?(:issues_analytics)

      navbar_sub_item(
        title: _('Issues'),
        path: 'issues_analytics#show',
        link: project_analytics_issues_analytics_path(project)
      )
    end

    def group_cycle_analytics_navbar_link(group, current_user)
      return unless ::Feature.enabled?(:group_level_cycle_analytics, default_enabled: true)
      return unless group_sidebar_link?(:cycle_analytics)

      navbar_sub_item(
        title: _('Value Stream'),
        path: 'groups/analytics/cycle_analytics#show',
        link: group_analytics_cycle_analytics_path(group)
      )
    end

    def productivity_analytics_navbar_link(group, current_user)
      return unless group_sidebar_link?(:productivity_analytics)

      navbar_sub_item(
        title: _('Productivity'),
        path: 'groups/analytics/productivity_analytics#show',
        link: group_analytics_productivity_analytics_path(group)
      )
    end

    def contribution_analytics_navbar_link(group, current_user)
      return unless group_sidebar_link?(:contribution_analytics)

      navbar_sub_item(
        title: _('Contribution'),
        path: 'groups/contribution_analytics#show',
        link: group_contribution_analytics_path(group),
        link_to_options: { data: { placement: 'right', qa_selector: 'contribution_analytics_link' } }
      )
    end

    def group_insights_navbar_link(group, current_user)
      return unless group_sidebar_link?(:group_insights)

      navbar_sub_item(
        title: _('Insights'),
        path: 'groups/insights#show',
        link:  group_insights_path(group),
        link_to_options: { class: 'shortcuts-group-insights', data: { qa_selector: 'group_insights_link' } }
      )
    end

    def issues_analytics_navbar_link(group, current_user)
      return unless group_sidebar_link?(:analytics)

      navbar_sub_item(
        title: _('Issues'),
        path: 'issues_analytics#show',
        link: group_issues_analytics_path(group)
      )
    end

    def insights_navbar_link(project, current_user)
      return unless project_nav_tab?(:project_insights)

      navbar_sub_item(
        title: _('Insights'),
        path: 'insights#show',
        link: project_insights_path(project),
        link_to_options: { class: 'shortcuts-project-insights', data: { qa_selector: 'project_insights_link' } }
      )
    end

    def code_review_analytics_navbar_link(project, current_user)
      return unless project_nav_tab?(:code_review)

      navbar_sub_item(
        title: _('Code Review'),
        path: 'projects/analytics/code_reviews#index',
        link: project_analytics_code_reviews_path(project)
      )
    end
  end
end
