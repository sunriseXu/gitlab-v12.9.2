# frozen_string_literal: true

require 'spec_helper'

describe API::Analytics::GroupActivityAnalytics do
  let_it_be(:group) { create(:group, :private) }

  let_it_be(:reporter) do
    create(:user).tap { |u| group.add_reporter(u) }
  end

  let_it_be(:anonymous_user) { create(:user) }

  shared_examples 'GET group_activity' do |activity|
    let(:feature_enabled) { true }
    let(:params) { { group_path: group.full_path } }
    let(:current_user) { reporter }
    let(:request) do
      get api("/analytics/group_activity/#{activity}_count", current_user), params: params
    end

    before do
      stub_licensed_features(group_activity_analytics: feature_enabled)
      request
    end

    it 'is successful' do
      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'is returns a count' do
      expect(response.parsed_body).to eq({ "#{activity}_count" => 0 })
    end

    context 'when feature is not available in plan' do
      let(:feature_enabled) { false }

      it 'is returns `forbidden`' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when `group_path` is not specified' do
      let(:params) { }

      it 'is returns `bad_request`' do
        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when user has no authorization to view a private group' do
      let(:current_user) { anonymous_user }

      it 'is returns `not_found`' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'GET /group_activity/issues_count' do
    it_behaves_like 'GET group_activity', 'issues'
  end

  context 'GET /group_activity/merge_requests_count' do
    it_behaves_like 'GET group_activity', 'merge_requests'
  end
end
