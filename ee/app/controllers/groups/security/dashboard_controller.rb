# frozen_string_literal: true
class Groups::Security::DashboardController < Groups::ApplicationController
  layout 'group'

  def show
    render :unavailable unless dashboard_available?
  end

  private

  def dashboard_available?
    group.feature_available?(:security_dashboard) &&
      can?(current_user, :read_group_security_dashboard, group)
  end
end
