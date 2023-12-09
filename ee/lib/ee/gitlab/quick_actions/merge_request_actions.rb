# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module MergeRequestActions
        extend ActiveSupport::Concern
        include ::Gitlab::QuickActions::Dsl

        included do
          desc _('Approve a merge request')
          explanation _('Approve the current merge request.')
          types MergeRequest
          condition do
            quick_action_target.persisted? && quick_action_target.can_approve?(current_user) && !quick_action_target.project.require_password_to_approve?
          end
          command :approve do
            if quick_action_target.can_approve?(current_user)
              ::MergeRequests::ApprovalService.new(quick_action_target.project, current_user).execute(quick_action_target)
              @execution_message[:approve] = _('Approved the current merge request.')
            end
          end

          desc _('Submit a review')
          explanation _('Submit the current review.')
          types MergeRequest
          condition do
            quick_action_target.persisted? && quick_action_target.project.feature_available?(:batch_comments, current_user)
          end
          command :submit_review do
            next if params[:review_id]

            result = DraftNotes::PublishService.new(quick_action_target, current_user).execute
            @execution_message[:submit_review] = if result[:status] == :success
                                                   _('Submitted the current review.')
                                                 else
                                                   result[:message]
                                                 end
          end
        end
      end
    end
  end
end
