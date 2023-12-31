# frozen_string_literal: true

module API
  module Analytics
    class GroupActivityAnalytics < Grape::API
      DESCRIPTION_DETAIL =
        'This feature is gated by the `:group_activity_analytics`'\
        ' feature flag, introduced in GitLab 12.9.'

      before do
        authenticate!
        not_found! unless Feature.enabled?(:group_activity_analytics)
      end

      helpers do
        def group
          @group ||= find_group!(params[:group_path])
        end

        def calculator
          @calculator ||=
            ::Analytics::GroupActivityCalculator.new(group, current_user)
        end
      end

      resource :analytics do
        resource :group_activity do
          desc 'Get count of recently created issues for group' do
            detail DESCRIPTION_DETAIL
            success EE::API::Entities::Analytics::GroupActivity::IssuesCount
          end

          params do
            requires :group_path, type: String, desc: 'Group Path'
          end

          get 'issues_count' do
            authorize! :read_group_activity_analytics, group
            present(
              calculator,
              with: EE::API::Entities::Analytics::GroupActivity::IssuesCount
            )
          end

          desc 'Get count of recently created merge requests for group' do
            detail DESCRIPTION_DETAIL
            success EE::API::Entities::Analytics::GroupActivity::MergeRequestsCount
          end

          params do
            requires :group_path, type: String, desc: 'Group Path'
          end

          get 'merge_requests_count' do
            authorize! :read_group_activity_analytics, group
            present(
              calculator,
              with: EE::API::Entities::Analytics::GroupActivity::MergeRequestsCount
            )
          end
        end
      end
    end
  end
end
