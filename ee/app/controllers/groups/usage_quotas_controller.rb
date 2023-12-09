# frozen_string_literal: true

class Groups::UsageQuotasController < Groups::ApplicationController
  before_action :authorize_admin_group!
  before_action :verify_usage_quotas_enabled!

  layout 'group_settings'

  def index
    @projects = @group.all_projects.with_shared_runners_limit_enabled.page(params[:page])
  end

  private

  def verify_usage_quotas_enabled!
    render_404 unless License.feature_available?(:usage_quotas)
    render_404 if @group.has_parent?
  end
end
