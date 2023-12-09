# frozen_string_literal: true

require 'spec_helper'

describe OperationsController do
  include Rails.application.routes.url_helpers

  PUBLIC = Gitlab::VisibilityLevel::PUBLIC
  PRIVATE = Gitlab::VisibilityLevel::PRIVATE

  let(:user) { create(:user) }

  shared_examples 'unlicensed' do |http_method, action|
    before do
      stub_licensed_features(operations_dashboard: false)
    end

    it 'renders 404' do
      public_send(http_method, action)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  before do
    stub_licensed_features(operations_dashboard: true)
    sign_in(user)
  end

  describe 'GET #index' do
    it_behaves_like 'unlicensed', :get, :index

    it 'renders index with 200 status code' do
      get :index

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end

    it 'renders regardless of the environments_dashboard feature flag' do
      stub_feature_flags(environments_dashboard: { enabled: false, thing: user })

      get :index

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        get :index

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #environments' do
    it_behaves_like 'unlicensed', :get, :environments

    it 'renders the view' do
      get :environments

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:environments)
    end

    it 'returns a 404 when the feature is disabled' do
      stub_feature_flags(environments_dashboard: { enabled: false, thing: user })

      get :environments

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'renders the view when the feature is disabled for a different user' do
      other_user = create(:user)
      stub_feature_flags(environments_dashboard: { enabled: false, thing: other_user })

      get :environments

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:environments)
    end

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        get :environments

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #list' do
    let(:now) { Time.now.change(usec: 0) }
    let(:project) { create(:project, :repository) }
    let(:commit) { project.commit }
    let!(:environment) { create(:environment, name: 'production', project: project) }
    let!(:deployment) { create(:deployment, :success, environment: environment, sha: commit.id, created_at: now, project: project) }

    it_behaves_like 'unlicensed', :get, :list

    shared_examples 'empty project list' do
      it 'returns an empty list' do
        get :list

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/list', dir: 'ee')
        expect(json_response['projects']).to eq([])
      end
    end

    context 'with added projects' do
      let(:alert1) { create(:prometheus_alert, project: project, environment: environment) }
      let(:alert2) { create(:prometheus_alert, project: project, environment: environment) }

      let!(:alert_events) do
        [
          create(:prometheus_alert_event, prometheus_alert: alert1),
          create(:prometheus_alert_event, prometheus_alert: alert2),
          create(:prometheus_alert_event, prometheus_alert: alert1),
          create(:prometheus_alert_event, :resolved, prometheus_alert: alert2)
        ]
      end

      let(:firing_alert_events) { alert_events.select(&:firing?) }
      let(:last_firing_alert) { firing_alert_events.last.prometheus_alert }

      let(:alert_path) do
        metrics_project_environment_path(project, environment)
      end

      let(:alert_json_path) do
        project_prometheus_alert_path(project, last_firing_alert.prometheus_metric_id,
                                      environment_id: environment, format: :json)
      end

      let(:expected_project) { json_response['projects'].first }

      before do
        user.update!(ops_dashboard_projects: [project])
        project.add_developer(user)
      end

      it 'returns a list of added projects' do
        get :list

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('dashboard/operations/list', dir: 'ee')

        expect(json_response['projects'].size).to eq(1)

        expect(expected_project['id']).to eq(project.id)
        expect(expected_project['remove_path'])
          .to eq(remove_operations_project_path(project_id: project.id))
        expect(expected_project['last_deployment']['id']).to eq(deployment.id)
        expect(expected_project['alert_count']).to eq(firing_alert_events.size)
        expect(expected_project['alert_path']).to eq(alert_path)
        expect(expected_project['last_alert']['id']).to eq(last_firing_alert.id)
      end

      it "returns as many projects as are in the user's dashboard" do
        projects = Array.new(8).map do
          project = create(:project)
          project.add_developer(user)
          project
        end
        user.update!(ops_dashboard_projects: projects)

        get :list

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('dashboard/operations/list', dir: 'ee')

        expect(json_response['projects'].size).to eq(8)
      end

      it 'returns a list of added projects regardless of the environments_dashboard feature flag' do
        stub_feature_flags(environments_dashboard: { enabled: false, thing: user })

        get :list

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('dashboard/operations/list', dir: 'ee')
        expect(json_response['projects'].size).to eq(1)
        expect(expected_project['id']).to eq(project.id)
      end

      context 'without sufficient access level' do
        before do
          project.add_reporter(user)
        end

        it_behaves_like 'empty project list'
      end
    end

    context 'without projects' do
      it_behaves_like 'empty project list'
    end

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        get :list

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #environments_list' do
    it_behaves_like 'unlicensed', :get, :environments_list

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        get :environments_list

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with an authenticated user without sufficient access_level' do
      it 'returns an empty project list' do
        project = create(:project)
        project.add_reporter(user)
        user.update!(ops_dashboard_projects: [project])

        get :environments_list

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['projects']).to eq([])
      end
    end

    context 'with an authenticated developer' do
      it 'returns an empty project list' do
        get :environments_list

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['projects']).to eq([])
      end

      it 'sets the polling interval header' do
        get :environments_list

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers[Gitlab::PollingInterval::HEADER_NAME]).to eq('120000')
      end

      it "returns an empty project list when the project is not in the developer's dashboard" do
        project = create(:project)
        project.add_developer(user)
        user.update!(ops_dashboard_projects: [])

        get :environments_list

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['projects']).to eq([])
      end

      context 'with a project in the dashboard' do
        let(:project) { create(:project, :with_avatar, :repository) }

        before do
          project.add_developer(user)
          user.update!(ops_dashboard_projects: [project])
        end

        it 'returns a 404 when the feature is disabled' do
          stub_feature_flags(environments_dashboard: { enabled: false, thing: user })
          environment = create(:environment, project: project)
          ci_build = create(:ci_build, project: project)
          create(:deployment, :success, project: project, environment: environment, deployable: ci_build)

          get :environments_list

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns a project when the feature is disabled for another user' do
          other_user = create(:user)
          stub_feature_flags(environments_dashboard: { enabled: false, thing: other_user })
          environment = create(:environment, project: project)
          ci_build = create(:ci_build, project: project)
          create(:deployment, :success, project: project, environment: environment, deployable: ci_build)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')
        end

        it 'returns a project without an environment' do
          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['id']).to eq(project.id)
          expect(project_json['name']).to eq(project.name)
          expect(project_json['namespace']['id']).to eq(project.namespace.id)
          expect(project_json['namespace']['name']).to eq(project.namespace.name)
          expect(project_json['environments']).to eq([])
        end

        it 'returns one project with one environment' do
          environment = create(:environment, project: project, name: 'staging')

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['id']).to eq(project.id)
          expect(project_json['name']).to eq(project.name)
          expect(project_json['namespace']['id']).to eq(project.namespace.id)
          expect(project_json['namespace']['name']).to eq(project.namespace.name)
          expect(project_json['environments'].count).to eq(1)
          expect(project_json['environments'].first['id']).to eq(environment.id)
          expect(project_json['environments'].first['environment_path']).to eq(project_environment_path(project, environment))
        end

        it 'returns multiple projects and environments' do
          project2 = create(:project)
          project2.add_developer(user)
          user.update!(ops_dashboard_projects: [project, project2])
          environment1 = create(:environment, project: project)
          environment2 = create(:environment, project: project)
          environment3 = create(:environment, project: project2)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')
          expect(json_response['projects'].count).to eq(2)
          expect(json_response['projects'].map { |p| p['id'] }.sort).to eq([project.id, project2.id])

          project_json = json_response['projects'].find { |p| p['id'] == project.id }
          project2_json = json_response['projects'].find { |p| p['id'] == project2.id }

          expect(project_json['environments'].map { |e| e['id'] }.sort).to eq([environment1.id, environment2.id])
          expect(project2_json['environments'].map { |e| e['id'] }).to eq([environment3.id])
        end

        it 'does not return environments that would be grouped into a folder' do
          create(:environment, project: project, name: 'review/test-feature')
          create(:environment, project: project, name: 'review/another-feature')

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['environments'].count).to eq(0)
        end

        it 'does not return environments that would be grouped into a folder even when there is only a single environment' do
          create(:environment, project: project, name: 'staging/test-feature')

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['environments'].count).to eq(0)
        end

        it 'returns an environment not in a folder' do
          environment = create(:environment, project: project, name: 'production')

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['environments'].count).to eq(1)
          expect(project_json['environments'].first['id']).to eq(environment.id)
        end

        it 'returns the last deployment for an environment' do
          environment = create(:environment, project: project)
          deployment = create(:deployment, :success, project: project, environment: environment)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first
          environment_json = project_json['environments'].first
          last_deployment_json = environment_json['last_deployment']

          expect(last_deployment_json['id']).to eq(deployment.id)
        end

        it "returns the last deployment's deployable" do
          environment = create(:environment, project: project)
          ci_build = create(:ci_build, project: project)
          create(:deployment, :success, project: project, environment: environment, deployable: ci_build)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first
          environment_json = project_json['environments'].first
          deployable_json = environment_json['last_deployment']['deployable']

          expect(deployable_json['id']).to eq(ci_build.id)
          expect(deployable_json['build_path']).to eq(project_job_path(project, ci_build))
        end

        it 'returns a failed deployment' do
          environment = create(:environment, project: project)
          deployment = create(:deployment, :failed, project: project, environment: environment)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first
          environment_json = project_json['environments'].first
          last_deployment_json = environment_json['last_deployment']

          expect(last_deployment_json['id']).to eq(deployment.id)
        end

        it 'returns a maximum of seven projects' do
          projects = Array.new(8).map do
            project = create(:project)
            project.add_developer(user)
            project
          end
          user.update!(ops_dashboard_projects: projects)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')
          expect(json_response['projects'].count).to eq(7)
        end

        it 'does not return a project for which the operations dashboard feature is unavailable' do
          stub_application_setting(check_namespace_plan: true)
          namespace = create(:namespace, visibility_level: PRIVATE)
          unavailable_project = create(:project, namespace: namespace, visibility_level: PRIVATE)
          unavailable_project.add_developer(user)
          user.update!(ops_dashboard_projects: [unavailable_project])

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')
          expect(json_response['projects'].count).to eq(0)
        end

        it 'returns seven projects when some projects do not have the dashboard feature available' do
          stub_application_setting(check_namespace_plan: true)

          public_namespace = create(:namespace, visibility_level: PUBLIC)
          public_projects = Array.new(7).map do
            project = create(:project, namespace: public_namespace, visibility_level: PUBLIC)
            project.add_developer(user)
            project
          end

          private_namespace = create(:namespace, visibility_level: PRIVATE)
          private_project = create(:project, namespace: private_namespace, visibility_level: PRIVATE)
          private_project.add_developer(user)

          all_projects = [private_project] + public_projects
          user.update!(ops_dashboard_projects: all_projects)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')
          expect(json_response['projects'].count).to eq(7)

          actual_ids = json_response['projects'].map { |p| p['id'].to_i }
          expected_ids = public_projects.map(&:id)

          expect(actual_ids).to contain_exactly(*expected_ids)
        end

        it 'returns a maximum of three environments for a project' do
          create(:environment, project: project)
          create(:environment, project: project)
          create(:environment, project: project)
          create(:environment, project: project)

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].first

          expect(project_json['environments'].count).to eq(3)
        end

        it 'returns a maximum of three environments for multiple projects' do
          project_b = create(:project)
          project_b.add_developer(user)
          create(:environment, project: project)
          create(:environment, project: project)
          create(:environment, project: project)
          create(:environment, project: project)
          create(:environment, project: project_b)
          create(:environment, project: project_b)
          create(:environment, project: project_b)
          create(:environment, project: project_b)
          user.update!(ops_dashboard_projects: [project, project_b])

          get :environments_list

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

          project_json = json_response['projects'].find { |p| p['id'] == project.id }
          project_b_json = json_response['projects'].find { |p| p['id'] == project_b.id }

          expect(project_json['environments'].count).to eq(3)
          expect(project_b_json['environments'].count).to eq(3)
        end

        context 'with a pipeline' do
          let(:project) { create(:project, :repository) }
          let(:commit) { project.commit }
          let(:environment) { create(:environment, project: project) }

          before do
            project.add_developer(user)
            user.update!(ops_dashboard_projects: [project])
          end

          it 'returns the last pipeline for an environment' do
            pipeline = create(:ci_pipeline, project: project, user: user, sha: commit.sha)
            ci_build = create(:ci_build, project: project, pipeline: pipeline)
            create(:deployment, :success, project: project, environment: environment, deployable: ci_build, sha: commit.sha)

            get :environments_list

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

            project_json = json_response['projects'].first
            environment_json = project_json['environments'].first
            last_pipeline_json = environment_json['last_pipeline']

            expect(last_pipeline_json['id']).to eq(pipeline.id)
            expect(last_pipeline_json['triggered']).to eq([])
            expect(last_pipeline_json['triggered_by']).to be_nil
          end

          it 'returns the last pipeline details' do
            pipeline = create(:ci_pipeline, project: project, user: user, sha: commit.sha, status: :canceled)
            ci_build = create(:ci_build, project: project, pipeline: pipeline)
            create(:deployment, :canceled, project: project, environment: environment, deployable: ci_build, sha: commit.sha)

            get :environments_list

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

            project_json = json_response['projects'].first
            environment_json = project_json['environments'].first
            last_pipeline_json = environment_json['last_pipeline']
            expected_details_path = project_pipeline_path(project, pipeline)

            expect(last_pipeline_json.dig('details', 'status', 'group')).to eq('canceled')
            expect(last_pipeline_json.dig('details', 'status', 'tooltip')).to eq('canceled')
            expect(last_pipeline_json.dig('details', 'status', 'details_path')).to eq(expected_details_path)
          end

          it 'returns an upstream pipeline' do
            project_b = create(:project, :repository)
            project_b.add_developer(user)
            commit_b = project_b.commit
            pipeline_b = create(:ci_pipeline, project: project_b, user: user, sha: commit_b.sha)
            ci_build_b = create(:ci_build, project: project_b, pipeline: pipeline_b)
            pipeline = create(:ci_pipeline, project: project, user: user, sha: commit.sha)
            ci_build = create(:ci_build, project: project, pipeline: pipeline)
            create(:deployment, :success, project: project, environment: environment, deployable: ci_build, sha: commit.sha)
            create(:ci_sources_pipeline, project: project, pipeline: pipeline, source_project: project_b, source_pipeline: pipeline_b, source_job: ci_build_b)

            get :environments_list

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

            project_json = json_response['projects'].first
            environment_json = project_json['environments'].first
            last_pipeline_json = environment_json['last_pipeline']
            triggered_by_pipeline_json = last_pipeline_json['triggered_by']

            expected_details_path = project_pipeline_path(project_b, pipeline_b)

            expect(last_pipeline_json['id']).to eq(pipeline.id)
            expect(triggered_by_pipeline_json['id']).to eq(pipeline_b.id)
            expect(triggered_by_pipeline_json.dig('details', 'status', 'details_path')).to eq(expected_details_path)
            expect(triggered_by_pipeline_json.dig('project', 'full_name')).to eq(project_b.full_name)
          end

          it 'returns a downstream pipeline' do
            project_b = create(:project, :repository)
            project_b.add_developer(user)
            commit_b = project_b.commit
            pipeline_b = create(:ci_pipeline, :failed, project: project_b, user: user, sha: commit_b.sha)
            create(:ci_build, :failed, project: project_b, pipeline: pipeline_b)
            pipeline = create(:ci_pipeline, project: project, user: user, sha: commit.sha)
            ci_build = create(:ci_build, project: project, pipeline: pipeline)
            create(:deployment, :success, project: project, environment: environment, deployable: ci_build, sha: commit.sha)
            create(:ci_sources_pipeline, project: project_b, pipeline: pipeline_b, source_project: project, source_pipeline: pipeline, source_job: ci_build)

            get :environments_list

            expect(response).to have_gitlab_http_status(:ok)
            expect(response).to match_response_schema('dashboard/operations/environments_list', dir: 'ee')

            project_json = json_response['projects'].first
            environment_json = project_json['environments'].first
            last_pipeline_json = environment_json['last_pipeline']

            expect(last_pipeline_json['triggered'].count).to eq(1)

            triggered_pipeline_json = last_pipeline_json['triggered'].first

            expected_details_path = project_pipeline_path(project_b, pipeline_b)

            expect(last_pipeline_json['id']).to eq(pipeline.id)
            expect(triggered_pipeline_json['id']).to eq(pipeline_b.id)
            expect(triggered_pipeline_json.dig('details', 'status', 'details_path')).to eq(expected_details_path)
            expect(triggered_pipeline_json.dig('details', 'status', 'group')).to eq('failed')
            expect(triggered_pipeline_json.dig('project', 'full_name')).to eq(project_b.full_name)
          end
        end
      end
    end
  end

  describe 'POST #create' do
    it_behaves_like 'unlicensed', :post, :create

    context 'without added projects' do
      let(:project_a) { create(:project) }
      let(:project_b) { create(:project) }

      before do
        project_a.add_developer(user)
        project_b.add_developer(user)
      end

      it 'adds projects to the dasboard' do
        post :create, params: { project_ids: [project_a.id, project_b.id.to_s] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/add', dir: 'ee')
        expect(json_response['added']).to contain_exactly(project_a.id, project_b.id)
        expect(json_response['duplicate']).to be_empty
        expect(json_response['invalid']).to be_empty

        user.reload
        expect(user.ops_dashboard_projects).to contain_exactly(project_a, project_b)
      end

      it 'adds projects to the dashboard regardless of the environments_dashboard feature flag' do
        stub_feature_flags(environments_dashboard: { enabled: false, thing: user })

        post :create, params: { project_ids: [project_a.id, project_b.id.to_s] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/add', dir: 'ee')
        expect(json_response['added']).to contain_exactly(project_a.id, project_b.id)
      end

      it 'cannot add a project twice' do
        post :create, params: { project_ids: [project_a.id, project_a.id] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/add', dir: 'ee')
        expect(json_response['added']).to contain_exactly(project_a.id)
        expect(json_response['duplicate']).to be_empty
        expect(json_response['invalid']).to be_empty

        user.reload
        expect(user.ops_dashboard_projects).to eq([project_a])
      end

      it 'does not add invalid project ids' do
        post :create, params: { project_ids: ['', -1, '-2'] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/add', dir: 'ee')
        expect(json_response['added']).to be_empty
        expect(json_response['duplicate']).to be_empty
        expect(json_response['invalid']).to contain_exactly('', '-1', '-2')

        user.reload
        expect(user.ops_dashboard_projects).to be_empty
      end
    end

    context 'with added project' do
      let(:project) { create(:project) }

      before do
        user.ops_dashboard_projects << project
        project.add_developer(user)
      end

      it 'does not add already added project' do
        post :create, params: { project_ids: [project.id] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_schema('dashboard/operations/add', dir: 'ee')
        expect(json_response['added']).to be_empty
        expect(json_response['duplicate']).to contain_exactly(project.id)
        expect(json_response['invalid']).to be_empty

        user.reload
        expect(user.ops_dashboard_projects).to eq([project])
      end
    end

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        post :create

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'DELETE #destroy' do
    it_behaves_like 'unlicensed', :delete, :destroy

    context 'with added projects' do
      let(:project) { create(:project) }

      before do
        user.ops_dashboard_projects << project
      end

      it 'removes a project successfully' do
        delete :destroy, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:ok)

        user.reload
        expect(user.ops_dashboard_projects).to eq([])
      end

      it 'removes a project regardless of the environments_dashboard feature flag' do
        stub_feature_flags(environments_dashboard: { enabled: false, thing: user })

        delete :destroy, params: { project_id: project.id }

        expect(response).to have_gitlab_http_status(:ok)
        user.reload
        expect(user.ops_dashboard_projects).to eq([])
      end
    end

    context 'without projects' do
      it 'cannot remove invalid project' do
        delete :destroy, params: { project_id: -1 }

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'with an anonymous user' do
      before do
        sign_out(user)
      end

      it 'redirects to sign-in page' do
        delete :destroy

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
