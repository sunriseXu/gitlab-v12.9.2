# frozen_string_literal: true

require 'spec_helper'

describe Projects::Analytics::CodeReviewsController, type: :request do
  let(:user) { create :user }
  let(:project) { create(:project) }

  before do
    login_as user
  end

  describe 'GET /*namespace_id/:project_id/analytics/code_reviews' do
    context 'for reporter+' do
      before do
        project.add_reporter(user)
      end

      context 'with code_review_analytics included in plan' do
        it 'is success' do
          get project_analytics_code_reviews_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'without code_review_analytics in plan' do
        before do
          stub_licensed_features(code_review_analytics: false)
        end

        it 'is not found' do
          get project_analytics_code_reviews_path(project)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'for guests' do
      before do
        project.add_guest(user)
      end

      it 'is not found' do
        get project_analytics_code_reviews_path(project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
