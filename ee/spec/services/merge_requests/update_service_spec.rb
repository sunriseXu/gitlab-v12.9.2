# frozen_string_literal: true

require 'spec_helper'

describe MergeRequests::UpdateService, :mailer do
  include ProjectForksHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:label) { create(:label, project: project) }
  let(:label2) { create(:label) }

  let(:merge_request) do
    create(
      :merge_request,
      :simple,
      title: 'Old title',
      description: "FYI #{user2.to_reference}",
      assignee_id: user3.id,
      source_project: project,
      author: create(:user)
    )
  end

  before do
    project.add_maintainer(user)
    project.add_developer(user2)
    project.add_developer(user3)
  end

  describe '#execute' do
    def update_merge_request(opts)
      described_class.new(project, user, opts).execute(merge_request)
    end

    context 'when code owners changes' do
      let(:code_owner) { create(:user) }

      before do
        project.add_maintainer(code_owner)

        allow(merge_request).to receive(:code_owners).and_return([], [code_owner])
      end

      it 'does not create any todos' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { Todo.count }
      end

      it 'does not send any emails' do
        expect do
          update_merge_request(title: 'New title')
        end.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when approvals_before_merge changes' do
      using RSpec::Parameterized::TableSyntax

      where(:project_value, :mr_before_value, :mr_after_value, :result) do
        3 | 4   | 5   | 5
        3 | 4   | nil | 3
        3 | nil | 5   | 5
      end

      with_them do
        let(:project) { create(:project, :repository, approvals_before_merge: project_value) }

        it "does not update" do
          merge_request.update(approvals_before_merge: mr_before_value)
          rule = create(:approval_merge_request_rule, merge_request: merge_request)

          update_merge_request(approvals_before_merge: mr_after_value)

          expect(rule.reload.approvals_required).to eq(0)
        end
      end
    end

    context 'merge' do
      let(:opts) { { merge: merge_request.diff_head_sha } }

      context 'when not approved' do
        before do
          merge_request.update(approvals_before_merge: 1)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }
        it { expect(@merge_request.state).to eq('opened') }
      end

      context 'when approved' do
        before do
          merge_request.update(approvals_before_merge: 1)
          merge_request.approvals.create(user: user)

          perform_enqueued_jobs do
            update_merge_request(opts)
            @merge_request = MergeRequest.find(merge_request.id)
          end
        end

        it { expect(@merge_request).to be_valid }
        it 'is in the "merge" state', :sidekiq_might_not_need_inline do
          expect(@merge_request.state).to eq('merged')
        end
      end
    end

    context 'when the approvers change' do
      let(:existing_approver) { create(:user) }
      let(:removed_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(removed_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
        end

        Todo.where(action: Todo::APPROVAL_REQUIRED).destroy_all # rubocop: disable DestroyAll
        ActionMailer::Base.deliveries.clear
      end

      context 'when an approver is added and an approver is removed' do
        before do
          perform_enqueued_jobs do
            update_merge_request(approver_ids: [new_approver, existing_approver].map(&:id).join(','))
          end
        end

        it 'adds todos for and sends emails to the new approvers' do
          expect(Todo.where(user: new_approver, action: Todo::APPROVAL_REQUIRED)).not_to be_empty
          should_email(new_approver)
        end

        it 'does not add todos for or send emails to the existing approvers' do
          expect(Todo.where(user: existing_approver, action: Todo::APPROVAL_REQUIRED)).to be_empty
          should_not_email(existing_approver)
        end

        it 'does not add todos for or send emails to the removed approvers' do
          expect(Todo.where(user: removed_approver, action: Todo::APPROVAL_REQUIRED)).to be_empty
          should_not_email(removed_approver)
        end
      end

      context 'when the approvers are set to the same values' do
        it 'does not create any todos' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { Todo.count }
        end

        it 'does not send any emails' do
          expect do
            update_merge_request(approver_ids: [existing_approver, removed_approver].map(&:id).join(','))
          end.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'updating target_branch' do
      let(:existing_approver) { create(:user) }
      let(:new_approver) { create(:user) }

      before do
        project.add_developer(existing_approver)
        project.add_developer(new_approver)

        perform_enqueued_jobs do
          update_merge_request(approver_ids: "#{existing_approver.id},#{new_approver.id}")
        end

        merge_request.target_project.update(reset_approvals_on_push: true)
        merge_request.approvals.create(user_id: existing_approver.id)
      end

      it 'resets approvals when target_branch is changed' do
        update_merge_request(target_branch: 'video')

        expect(merge_request.reload.approvals).to be_empty
      end

      it 'creates new todos for the approvers' do
        expect(Todo.where(action: Todo::APPROVAL_REQUIRED).map(&:user)).to contain_exactly(new_approver, existing_approver)
      end
    end

    context 'updating blocking merge requests' do
      it 'delegates to MergeRequests::UpdateBlocksService' do
        expect(MergeRequests::UpdateBlocksService)
          .to receive(:extract_params!)
          .and_return(:extracted_params)

        expect_next_instance_of(MergeRequests::UpdateBlocksService) do |service|
          expect(service.merge_request).to eq(merge_request)
          expect(service.current_user).to eq(user)
          expect(service.params).to eq(:extracted_params)

          expect(service).to receive(:execute)
        end

        update_merge_request({})
      end
    end

    context 'when reassigned' do
      it 'schedules for analytics metric update' do
        expect(Analytics::CodeReviewMetricsWorker)
          .to receive(:perform_async).with('Analytics::RefreshReassignData', merge_request.id, {})

        update_merge_request({ assignee_ids: [user2.id] })
      end

      context 'when code_review_analytics is not available' do
        before do
          stub_licensed_features(code_review_analytics: false)
        end

        it 'does not schedule for analytics metric update' do
          expect(Analytics::CodeReviewMetricsWorker).not_to receive(:perform_async)

          update_merge_request({ assignee_ids: [user2.id] })
        end
      end
    end
  end
end
