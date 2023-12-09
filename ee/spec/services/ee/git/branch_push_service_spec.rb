# frozen_string_literal: true

require 'spec_helper'

describe Git::BranchPushService do
  include RepoHelpers

  let_it_be(:user) { create(:user) }
  let(:blankrev)   { Gitlab::Git::BLANK_SHA }
  let(:oldrev)     { sample_commit.parent_id }
  let(:newrev)     { sample_commit.id }
  let(:ref)        { 'refs/heads/master' }

  let(:params) do
    { change: { oldrev: oldrev, newrev: newrev, ref: ref } }
  end

  subject do
    described_class.new(project, user, params)
  end

  context 'with pull project' do
    let_it_be(:project) { create(:project, :repository, :mirror) }

    before do
      allow(project.repository).to receive(:commit).and_call_original
      allow(project.repository).to receive(:commit).with("master").and_return(nil)
    end

    context 'deleted branch' do
      let(:newrev) { blankrev }

      it 'handles when remote branch exists' do
        expect(project.repository).to receive(:commit).with("refs/remotes/upstream/master").and_return(sample_commit)

        subject.execute
      end
    end

    context 'ElasticSearch indexing', :elastic do
      before do
        stub_ee_application_setting(elasticsearch_indexing?: true)
      end

      context 'when the project is locked by elastic.rake', :clean_gitlab_redis_shared_state do
        before do
          Gitlab::Redis::SharedState.with { |redis| redis.sadd(:elastic_projects_indexing, project.id) }
        end

        it 'does not run ElasticCommitIndexerWorker' do
          expect(ElasticCommitIndexerWorker).not_to receive(:perform_async)

          subject.execute
        end
      end

      it 'runs ElasticCommitIndexerWorker' do
        expect(ElasticCommitIndexerWorker).to receive(:perform_async).with(project.id, oldrev, newrev)

        subject.execute
      end

      it "triggers indexer when push to default branch", :sidekiq_might_not_need_inline do
        expect_any_instance_of(Gitlab::Elastic::Indexer).to receive(:run)

        subject.execute
      end

      context 'when push to non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not trigger indexer when push to non-default branch' do
          expect_any_instance_of(Gitlab::Elastic::Indexer).not_to receive(:run)

          subject.execute
        end
      end

      context 'when limited indexing is on' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        context 'when the project is not enabled specifically' do
          it 'does not run ElasticCommitIndexerWorker' do
            expect(ElasticCommitIndexerWorker).not_to receive(:perform_async)

            subject.execute
          end
        end

        context 'when a project is enabled specifically' do
          before do
            create :elasticsearch_indexed_project, project: project
          end

          it 'runs ElasticCommitIndexerWorker' do
            expect(ElasticCommitIndexerWorker).to receive(:perform_async).with(project.id, oldrev, newrev)

            subject.execute
          end
        end

        context 'when a group is enabled' do
          let(:group) { create(:group) }
          let(:project) { create(:project, :repository, :mirror, group: group) }

          before do
            create :elasticsearch_indexed_namespace, namespace: group
          end

          it 'runs ElasticCommitIndexerWorker' do
            expect(ElasticCommitIndexerWorker).to receive(:perform_async).with(project.id, oldrev, newrev)

            subject.execute
          end
        end
      end
    end

    context 'External pull requests' do
      it 'runs UpdateExternalPullRequestsWorker' do
        expect(UpdateExternalPullRequestsWorker).to receive(:perform_async).with(project.id, user.id, ref)

        subject.execute
      end

      context 'when project is not mirror' do
        before do
          allow(project).to receive(:mirror?).and_return(false)
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          subject.execute
        end
      end

      context 'when param skips pipeline creation' do
        before do
          params[:create_pipelines] = false
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          subject.execute
        end
      end
    end
  end

  context 'Jira Connect hooks' do
    let_it_be(:project) { create(:project, :repository) }
    let(:branch_to_sync) { nil }
    let(:commits_to_sync) { [] }

    shared_examples 'enqueues Jira sync worker' do
      it do
        Sidekiq::Testing.fake! do
          expect(JiraConnect::SyncBranchWorker).to receive(:perform_async)
            .with(project.id, branch_to_sync, commits_to_sync)
            .and_call_original

          expect { subject.execute }.to change(JiraConnect::SyncBranchWorker.jobs, :size).by(1)
        end
      end
    end

    shared_examples 'does not enqueue Jira sync worker' do
      it do
        Sidekiq::Testing.fake! do
          expect { subject.execute }.not_to change(JiraConnect::SyncBranchWorker.jobs, :size)
        end
      end
    end

    context 'has Jira dev panel integration license' do
      before do
        stub_licensed_features(jira_dev_panel_integration: true)
      end

      context 'with a Jira subscription' do
        before do
          create(:jira_connect_subscription, namespace: project.namespace)
        end

        context 'branch name contains Jira issue key' do
          let(:branch_to_sync) { 'branch-JIRA-123' }
          let(:ref) { "refs/heads/#{branch_to_sync}" }

          it_behaves_like 'enqueues Jira sync worker'
        end

        context 'commit message contains Jira issue key' do
          let(:commits_to_sync) { [newrev] }

          before do
            allow_any_instance_of(Commit).to receive(:safe_message).and_return('Commit with key JIRA-123')
          end

          it_behaves_like 'enqueues Jira sync worker'
        end

        context 'branch name and commit message does not contain Jira issue key' do
          it_behaves_like 'does not enqueue Jira sync worker'
        end
      end

      context 'without a Jira subscription' do
        it_behaves_like 'does not enqueue Jira sync worker'
      end
    end

    context 'does not have Jira dev panel integration license' do
      before do
        stub_licensed_features(jira_dev_panel_integration: false)
      end

      it_behaves_like 'does not enqueue Jira sync worker'
    end
  end
end
