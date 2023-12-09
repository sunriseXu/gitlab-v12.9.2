# frozen_string_literal: true

require 'spec_helper'

describe API::ProjectMirror do
  describe 'POST /projects/:id/mirror/pull' do
    let(:visibility) { Gitlab::VisibilityLevel::PUBLIC }
    let(:project_mirrored) { create(:project, :repository, :mirror, :import_finished, visibility: visibility) }

    def do_post(user: nil, params: {}, headers: { 'X-Hub-Signature' => 'signature' })
      api_path = api("/projects/#{project_mirrored.id}/mirror/pull", user)

      post api_path, params: params, headers: headers
    end

    context 'when authenticated via GitHub signature' do
      before do
        Grape::Endpoint.before_each do |endpoint|
          allow(endpoint).to receive(:valid_github_signature?).and_return(true)
          allow(endpoint).to receive(:project).and_return(project_mirrored)
        end
      end

      after do
        Grape::Endpoint.before_each nil
      end

      context 'when project is not mirrored' do
        before do
          allow(project_mirrored).to receive(:mirror?).and_return(false)

          do_post
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when project is mirrored' do
        before do
          allow_next_instance_of(Projects::UpdateMirrorService) do |instance|
            allow(instance).to receive(:execute).and_return(status: :success)
          end
        end

        context 'when "pull_request" event is received' do
          let(:create_pipeline_service) { instance_double(Ci::CreatePipelineService) }
          let(:branch) { project_mirrored.repository.branches.first }
          let(:source_branch) { branch.name }
          let(:source_sha) { branch.target }
          let(:action) { 'opened' }

          let(:params) do
            {
              pull_request: {
                number: 123,
                head: {
                  ref: source_branch,
                  sha: source_sha,
                  repo: { full_name: 'the-repo' }
                },
                base: {
                  ref: 'master',
                  sha: 'a09386439ca39abe575675ffd4b89ae824fec22f',
                  repo: { full_name: 'the-repo' }
                }
              },
              action: action
            }
          end

          let(:pipeline_params) do
            {
              ref: Gitlab::Git::BRANCH_REF_PREFIX + branch.name,
              source_sha: branch.target,
              target_sha: 'a09386439ca39abe575675ffd4b89ae824fec22f'
            }
          end

          before do
            stub_licensed_features(ci_cd_projects: true, github_project_service_integration: true)
          end

          it 'triggers a pipeline for pull request' do
            expect(Ci::CreatePipelineService)
              .to receive(:new)
              .with(project_mirrored, project_mirrored.mirror_user, pipeline_params)
              .and_return(create_pipeline_service)

            expect(create_pipeline_service)
              .to receive(:execute)
              .with(:external_pull_request_event, any_args)

            do_post(params: params)

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'when any param is missing' do
            let(:source_sha) { nil }

            it 'returns the error message' do
              do_post(params: params)

              expect(response).to have_gitlab_http_status(:bad_request)
            end
          end

          context 'when action is not supported' do
            let(:action) { 'assigned' }

            it 'ignores it and return success status' do
              expect(Ci::CreatePipelineService).not_to receive(:new)

              do_post(params: params)

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end

          context 'when authenticated as user' do
            let(:user) { create(:user) }

            it 'triggers a pipeline for pull request' do
              project_member(:maintainer, user)

              expect(Ci::CreatePipelineService)
                .to receive(:new)
                .with(project_mirrored, user, pipeline_params)
                .and_return(create_pipeline_service)

              expect(create_pipeline_service)
                .to receive(:execute)
                .with(:external_pull_request_event, any_args)

              do_post(params: params, user: user, headers: {})

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          context 'when ci_cd_projects is not available' do
            before do
              stub_licensed_features(ci_cd_projects: false, github_project_service_integration: true)
            end

            it 'returns the error message' do
              do_post(params: params)

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end

          context 'when github_project_service_integration is not available' do
            before do
              stub_licensed_features(github_project_service_integration: false, ci_cd_projects: true)
            end

            it 'returns the error message' do
              do_post(params: params)

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when "push" event is received' do
          shared_examples_for 'an API endpoint that triggers pull mirroring operation' do
            it 'executes UpdateAllMirrorsWorker' do
              expect(project_mirrored.import_state).to receive(:force_import_job!).and_call_original
              expect(UpdateAllMirrorsWorker).to receive(:perform_async).once

              do_post

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          shared_examples_for 'an API endpoint that does not trigger pull mirroring operation' do |status_code|
            it "does not execute UpdateAllMirrorsWorker and returns #{status_code}" do
              expect(UpdateAllMirrorsWorker).not_to receive(:perform_async)
              do_post

              expect(response).to have_gitlab_http_status(status_code)
            end
          end

          let(:state) { :none }

          before do
            project_mirrored
              .import_state
              .update!(status: state, next_execution_timestamp: 10.minutes.from_now)
          end

          context 'when import state is none' do
            it_behaves_like 'an API endpoint that triggers pull mirroring operation'
          end

          context 'when import state is failed' do
            let(:state) { :failed }

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'

            context "and retried more than #{Gitlab::Mirror::MAX_RETRY} times" do
              before do
                project_mirrored
                  .import_state
                  .update!(retry_count: Gitlab::Mirror::MAX_RETRY + 1)
              end

              it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :forbidden
            end
          end

          context 'when import state is finished' do
            let(:state) { :finished }

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'
          end

          context 'when import state is scheduled' do
            let(:state) { :scheduled }

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :ok
          end

          context 'when import state is started' do
            let(:state) { :started }

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :ok
          end

          context 'when authenticated as user' do
            let(:user) { create(:user) }

            context 'is authenticated as developer' do
              it 'returns forbidden error' do
                project_member(:developer, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as reporter' do
              it 'returns forbidden error' do
                project_member(:reporter, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as guest' do
              it 'returns forbidden error' do
                project_member(:guest, user)

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:forbidden)
              end
            end

            context 'is authenticated as maintainer' do
              it 'triggers the pull mirroring operation' do
                project_member(:maintainer, user)

                expect(StartPullMirroringService)
                  .to receive(:new)
                  .with(project_mirrored, user)
                  .and_call_original

                do_post(user: user, headers: {})

                expect(response).to have_gitlab_http_status(:ok)
              end
            end

            context 'is authenticated as owner' do
              it 'triggers the pull mirroring operation' do
                expect(StartPullMirroringService)
                  .to receive(:new)
                  .with(project_mirrored, project_mirrored.creator)
                  .and_call_original

                do_post(user: project_mirrored.creator, headers: {})

                expect(response).to have_gitlab_http_status(:ok)
              end
            end
          end

          context 'when repository_mirrors feature is not available' do
            before do
              stub_licensed_features(repository_mirrors: false)
              project_mirrored.clear_memoization(:licensed_feature_available)
            end

            it_behaves_like 'an API endpoint that does not trigger pull mirroring operation', :bad_request
          end

          context 'when repository_mirrors feature is available' do
            before do
              stub_licensed_features(repository_mirrors: true)
              project_mirrored.clear_memoization(:licensed_feature_available)
            end

            it_behaves_like 'an API endpoint that triggers pull mirroring operation'
          end
        end

        def project_member(role, user)
          create(:project_member, role, user: user, project: project_mirrored)
        end
      end
    end

    context 'when not authenticated' do
      before do
        Grape::Endpoint.before_each do |endpoint|
          allow(endpoint).to receive(:valid_github_signature?).and_return(false)
        end
      end

      after do
        Grape::Endpoint.before_each nil
      end

      context 'with public project' do
        let(:visibility) { Gitlab::VisibilityLevel::PUBLIC }

        it 'returns a 401 status' do
          do_post

          expect(response).to have_gitlab_http_status(:unauthorized)
        end
      end

      context 'with internal project' do
        let(:visibility) { Gitlab::VisibilityLevel::INTERNAL }

        it 'returns a 404 status' do
          do_post

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with private project' do
        let(:visibility) { Gitlab::VisibilityLevel::PRIVATE }

        it 'returns a 404 status' do
          do_post

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
