# frozen_string_literal: true

class Analytics::AnalyticsController < Analytics::ApplicationController
  def index
    if Feature.disabled?(:group_level_cycle_analytics, default_enabled: true) && Gitlab::Analytics.cycle_analytics_enabled?
      redirect_to analytics_cycle_analytics_path
    elsif can?(current_user, :read_instance_statistics)
      redirect_to instance_statistics_dev_ops_score_index_path
    else
      render_404
    end
  end
end
