# frozen_string_literal: true

module SubscriptionsHelper
  include ::Gitlab::Utils::StrongMemoize

  def subscription_data
    {
      setup_for_company: (current_user.setup_for_company == true).to_s,
      full_name: current_user.name,
      plan_data: plan_data.to_json,
      plan_id: params[:plan_id],
      new_user: new_user?.to_s,
      group_data: group_data.to_json
    }
  end

  def plan_title
    strong_memoize(:plan_title) do
      plan = plan_data.find { |plan| plan[:id] == params[:plan_id] }
      plan[:code].titleize if plan
    end
  end

  private

  def new_user?
    return false unless request.referer.present?

    URI.parse(request.referer).path.in?([users_sign_up_welcome_path, users_sign_up_update_registration_path])
  end

  def plan_data
    FetchSubscriptionPlansService.new(plan: :free).execute
      .map(&:symbolize_keys)
      .reject { |plan| plan[:free] }
      .map { |plan| plan.slice(:id, :code, :price_per_year) }
  end

  def group_data
    current_user.managed_free_namespaces.map do |namespace|
      {
        id: namespace.id,
        name: namespace.name,
        users: namespace.member_count
      }
    end
  end
end
