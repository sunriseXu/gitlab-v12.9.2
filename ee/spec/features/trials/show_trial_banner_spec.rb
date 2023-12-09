# frozen_string_literal: true

require 'spec_helper'

describe 'Show trial banner', :js do
  include StubRequests

  let!(:user) { create(:user) }
  let!(:group) { create(:group) }
  let!(:gold_plan) { create(:gold_plan) }
  let(:plans_data) do
    JSON.parse(File.read(Rails.root.join('ee/spec/fixtures/gitlab_com_plans.json'))).map do |data|
      data.deep_symbolize_keys
    end
  end

  before do
    stub_application_setting(check_namespace_plan: true)
    allow(Gitlab).to receive(:com?).and_return(true).at_least(:once)
    stub_full_request("#{EE::SUBSCRIPTIONS_URL}/gitlab_plans?plan=free")
      .to_return(status: 200, body: plans_data.to_json)

    group.add_owner(user)
    create(:gitlab_subscription, namespace: user.namespace, hosted_plan: gold_plan, trial: true, trial_ends_on: Date.current + 1.month)
    create(:gitlab_subscription, namespace: group, hosted_plan: gold_plan, trial: true, trial_ends_on: Date.current + 1.month)

    gitlab_sign_in(user)
  end

  context "when user's trial is active" do
    it 'renders congratulations banner for user in profile billing page' do
      visit profile_billings_path + '?trial=true'

      expect(page).to have_content('Congratulations, your new trial is activated')
    end
  end

  context "when group's trial is active" do
    it 'renders congratulations banner for group in group details page' do
      visit group_path(group, trial: true)

      expect(find('.user-callout').text).to have_content('Congratulations, your new trial is activated')
    end

    it 'does not render congratulations banner for group in group billing page' do
      visit group_billings_path(group, trial: true)

      expect(page).not_to have_content('Congratulations, your new trial is activated')
    end
  end
end
