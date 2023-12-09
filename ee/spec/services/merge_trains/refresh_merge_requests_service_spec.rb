# frozen_string_literal: true

require 'spec_helper'

describe MergeTrains::RefreshMergeRequestsService do
  include ExclusiveLeaseHelpers

  let(:project) { create(:project) }
  let_it_be(:maintainer_1) { create(:user) }
  let_it_be(:maintainer_2) { create(:user) }
  let(:service) { described_class.new(project, maintainer_1) }

  before do
    project.add_maintainer(maintainer_1)
    project.add_maintainer(maintainer_2)
  end

  describe '#execute', :clean_gitlab_redis_queues do
    subject { service.execute(merge_request) }

    let!(:merge_request_1) do
      create(:merge_request, :on_train, train_creator: maintainer_1,
        source_branch: 'feature', source_project: project,
        target_branch: 'master', target_project: project)
    end

    let!(:merge_request_2) do
      create(:merge_request, :on_train, train_creator: maintainer_2,
        source_branch: 'signed-commits', source_project: project,
        target_branch: 'master', target_project: project)
    end

    let(:refresh_service_1) { double }
    let(:refresh_service_2) { double }
    let(:refresh_service_1_result) { { status: :success } }
    let(:refresh_service_2_result) { { status: :success } }

    before do
      allow(MergeTrains::RefreshMergeRequestService)
        .to receive(:new).with(project, maintainer_1, anything) { refresh_service_1 }
      allow(MergeTrains::RefreshMergeRequestService)
        .to receive(:new).with(project, maintainer_2, anything) { refresh_service_2 }

      allow(refresh_service_1).to receive(:execute) { refresh_service_1_result }
      allow(refresh_service_2).to receive(:execute) { refresh_service_2_result }
    end

    context 'when merge request 1 is passed' do
      let(:merge_request) { merge_request_1 }

      it 'executes RefreshMergeRequestService to all the following merge requests' do
        expect(refresh_service_1).to receive(:execute).with(merge_request_1)
        expect(refresh_service_2).to receive(:execute).with(merge_request_2)

        subject
      end

      context 'when merge_trains_parallel_pipelines feature flag is disabled' do
        before do
          stub_feature_flags(merge_trains_parallel_pipelines: false)
        end

        it 'does not refresh merge request 2' do
          expect(refresh_service_1).to receive(:execute).with(merge_request_1)
          expect(refresh_service_2).not_to receive(:execute).with(merge_request_2)

          subject
        end
      end

      context 'when refresh service 1 returns error status' do
        let(:refresh_service_1_result) { { status: :error, message: 'Failed to create ref' } }

        it 'specifies require_recreate to refresh service 2' do
          allow(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: true) { refresh_service_2 }

          subject
        end
      end

      context 'when refresh service 1 returns success status and did not create a pipeline' do
        let(:refresh_service_1_result) { { status: :success, pipeline_created: false } }

        it 'does not specify require_recreate to refresh service 2' do
          allow(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: false) { refresh_service_2 }

          subject
        end
      end

      context 'when refresh service 1 returns success status and created a pipeline' do
        let(:refresh_service_1_result) { { status: :success, pipeline_created: true } }

        it 'specifies require_recreate to refresh service 2' do
          allow(MergeTrains::RefreshMergeRequestService)
            .to receive(:new).with(project, maintainer_2, require_recreate: true) { refresh_service_2 }

          subject
        end
      end

      context 'when merge request 1 is not on a merge train' do
        let(:merge_request) { merge_request_1 }
        let!(:merge_request_1) { create(:merge_request) }

        it 'does not refresh' do
          expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)

          subject
        end
      end

      context 'when merge request 1 was on a merge train' do
        before do
          allow(merge_request_1.merge_train).to receive(:cleanup_ref)
          merge_request_1.merge_train.update_column(:status, MergeTrain.state_machines[:status].states[:merged].value)
        end

        it 'does not refresh' do
          expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)

          subject
        end
      end

      context 'when the other thread has already been processing the merge train' do
        let(:lock_key) { "batch_pop_queueing:lock:merge_trains:#{merge_request.target_project_id}:#{merge_request.target_branch}" }

        before do
          stub_exclusive_lease_taken(lock_key)
        end

        it 'does not refresh' do
          expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)

          subject
        end

        it 'enqueues the merge request id to BatchPopQueueing' do
          expect_next_instance_of(Gitlab::BatchPopQueueing) do |queuing|
            expect(queuing).to receive(:enqueue).with([merge_request_1.id], anything).and_call_original
          end

          subject
        end
      end
    end

    context 'when merge request 2 is passed' do
      let(:merge_request) { merge_request_2 }

      it 'executes RefreshMergeRequestService to all the following merge requests' do
        expect(refresh_service_1).not_to receive(:execute).with(merge_request_1)
        expect(refresh_service_2).to receive(:execute).with(merge_request_2)

        subject
      end

      context 'when merge request 1 was tried to be refreshed while the system is refreshing merge request 2' do
        before do
          allow_any_instance_of(described_class).to receive(:unsafe_refresh).with(merge_request_2) do
            service.execute(merge_request_1)
          end
        end

        it 'refreshes the merge request 1 later with AutoMergeProcessWorker' do
          expect(AutoMergeProcessWorker).to receive(:perform_async).with(merge_request_1.id).once

          subject
        end

        context 'when merge request 1 has already been merged' do
          before do
            allow(merge_request_1.merge_train).to receive(:cleanup_ref)
            merge_request_1.merge_train.update_column(:status, MergeTrain.state_machines[:status].states[:merged].value)
          end

          it 'does not refresh the merge request 1' do
            expect(AutoMergeProcessWorker).not_to receive(:perform_async).with(merge_request_1.id)

            subject
          end
        end
      end
    end
  end

  describe '#max_concurrency' do
    subject { service.send(:max_concurrency) }

    context 'when `merge_trains_parallel_pipelines` feature flag is enabled' do
      before do
        stub_feature_flags(merge_trains_parallel_pipelines: true)
      end

      context 'when `merge_trains_high_concurrency` feature flag is enabled' do
        before do
          stub_feature_flags(merge_trains_high_concurrency: true)
        end

        it 'returns high concurrency' do
          is_expected.to eq(described_class::HIGH_CONCURRENCY)
        end
      end

      context 'when `merge_trains_high_concurrency` feature flag is disabled' do
        before do
          stub_feature_flags(merge_trains_high_concurrency: false)
        end

        context 'when `merge_trains_medium_concurrency` feature flag is enabled' do
          before do
            stub_feature_flags(merge_trains_medium_concurrency: true)
          end

          it 'returns medium concurrency' do
            is_expected.to eq(described_class::MEDIUM_CONCURRENCY)
          end
        end

        context 'when `merge_trains_medium_concurrency` feature flag is disabled' do
          before do
            stub_feature_flags(merge_trains_medium_concurrency: false)
          end

          it 'returns low concurrency' do
            is_expected.to eq(described_class::LOW_CONCURRENCY)
          end
        end
      end
    end

    context 'when `merge_trains_parallel_pipelines` feature flag is disabled' do
      before do
        stub_feature_flags(merge_trains_parallel_pipelines: false)
      end

      it 'returns no concurrency' do
        is_expected.to eq(described_class::NO_CONCURRENCY)
      end
    end
  end
end
