# frozen_string_literal: true

class Groups::BillingsController < Groups::ApplicationController
  before_action :authorize_admin_group!
  before_action :verify_namespace_plan_check_enabled

  layout 'group_settings'

  def index
    @top_most_group = @group.root_ancestor if @group.has_parent?
    current_plan = (@top_most_group || @group).plan_name_for_upgrading
    @plans_data = FetchSubscriptionPlansService.new(plan: current_plan).execute
  end
end
