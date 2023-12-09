# frozen_string_literal: true

require 'spec_helper'

describe API::Projects do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, namespace: user.namespace) }

  describe 'GET /projects' do
    it 'does not break on license checks' do
      enable_namespace_license_check!

      create(:project, :private, namespace: user.namespace)
      create(:project, :public, namespace: user.namespace)

      get api('/projects', user)

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'filters by verification flags' do
      let(:project1) { create(:project, namespace: user.namespace) }

      it 'filters by :repository_verification_failed' do
        create(:repository_state, :repository_failed, project: project)
        create(:repository_state, :wiki_failed, project: project1)

        get api('/projects', user), params: { repository_checksum_failed: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq project.id
      end

      it 'filters by :wiki_verification_failed' do
        create(:repository_state, :wiki_failed, project: project)
        create(:repository_state, :repository_failed, project: project1)

        get api('/projects', user), params: { wiki_checksum_failed: true }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq project.id
      end
    end
  end

  describe 'GET /projects/:id' do
    context 'with external authorization' do
      let(:project) do
        create(:project,
               namespace: user.namespace,
               external_authorization_classification_label: 'the-label')
      end

      before do
        stub_licensed_features(external_authorization_service_api_management: true)
      end

      context 'when the user has access to the project' do
        before do
          external_service_allow_access(user, project)
        end

        it 'includes the label in the response' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['external_authorization_classification_label']).to eq('the-label')
        end
      end

      context 'when the external service denies access' do
        before do
          external_service_deny_access(user, project)
        end

        it 'returns a 404' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'it does not return the label when the feature is not available' do
        before do
          stub_licensed_features(external_authorization_service_api_management: false)
        end

        it 'does not include the label in the response' do
          get api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['external_authorization_classification_label']).to be_nil
        end
      end

      context 'with ip restriction' do
        let(:group) { create :group, :private }

        before do
          create(:ip_restriction, group: group)
          group.add_maintainer(user)
          project.update(namespace: group)
        end

        context 'when the group_ip_restriction feature is not available' do
          before do
            stub_licensed_features(group_ip_restriction: false)
          end

          it 'returns 200' do
            get api("/projects/#{project.id}", user)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when the group_ip_restriction feature is available' do
          before do
            stub_licensed_features(group_ip_restriction: true)
          end

          it 'returns 404 for request from ip not in the range' do
            get api("/projects/#{project.id}", user)

            expect(response).to have_gitlab_http_status(:not_found)
          end

          it 'returns 200 for request from ip in the range' do
            get api("/projects/#{project.id}", user), headers: { 'REMOTE_ADDR' => '192.168.0.0' }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    describe 'packages_enabled attribute' do
      it 'is exposed when the feature is available' do
        stub_licensed_features(packages: true)

        get api("/projects/#{project.id}", user)

        expect(json_response).to have_key 'packages_enabled'
      end

      it 'is not exposed when the feature is not available' do
        stub_licensed_features(packages: false)

        get api("/projects/#{project.id}", user)

        expect(json_response).not_to have_key 'packages_enabled'
      end
    end

    describe 'service desk attributes' do
      it 'are exposed when the feature is available' do
        stub_licensed_features(service_desk: true)

        get api("/projects/#{project.id}", user)

        expect(json_response).to have_key 'service_desk_enabled'
        expect(json_response).to have_key 'service_desk_address'
      end

      it 'are not exposed when the feature is not available' do
        stub_licensed_features(service_desk: false)

        get api("/projects/#{project.id}", user)

        expect(json_response).not_to have_key 'service_desk_enabled'
        expect(json_response).not_to have_key 'service_desk_address'
      end
    end

    describe 'marked_for_deletion attribute' do
      it 'exposed when the feature is available' do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)

        get api("/projects/#{project.id}", user)

        expect(json_response).to have_key 'marked_for_deletion_at'
      end

      it 'not exposed when the feature is not available' do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)

        get api("/projects/#{project.id}", user)

        expect(json_response).not_to have_key 'marked_for_deletion_at'
      end
    end
  end

  # Assumes the following variables are defined:
  # group
  # project
  # new_project_name
  # api_call
  shared_examples 'creates projects with templates' do
    before do
      group.add_maintainer(user)
      stub_licensed_features(custom_project_templates: true)
      stub_ee_application_setting(custom_project_templates_group_id: group.id)
    end

    it 'creates a project using a template' do
      expect(ProjectExportWorker).to receive(:perform_async).and_call_original

      Sidekiq::Testing.fake! do
        expect { api_call }.to change { Project.count }.by(1)
      end

      expect(response).to have_gitlab_http_status(:created)

      project = Project.find(json_response['id'])
      expect(project.name).to eq(new_project_name)
    end

    it 'returns a 400 error for an invalid template name' do
      project_params.delete(:template_project_id)
      project_params[:template_name] = 'bogus-template'

      expect { api_call }.not_to change { Project.count }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['template_name']).to eq(["'bogus-template' is unknown or invalid"])
    end

    it 'returns a 400 error for an invalid template ID' do
      project_params.delete(:template_name)
      new_project = create(:project)
      project_params[:template_project_id] = new_project.id

      expect { api_call }.not_to change { Project.count }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['message']['template_project_id']).to eq(["#{new_project.id} is unknown or invalid"])
    end
  end

  shared_context 'base instance template models' do
    let(:group) { create(:group) }
    let!(:project) { create(:project, :public, namespace: group) }
    let(:new_project_name) { "project-#{SecureRandom.hex}" }
  end

  shared_context 'instance template name' do
    include_context 'base instance template models'

    let(:project_params) do
      {
        template_name: project.name,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        namespace_id: group.id
      }
    end
  end

  shared_context 'instance template ID' do
    include_context 'base instance template models'

    let(:project_params) do
      {
        template_project_id: project.id,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        namespace_id: group.id
      }
    end
  end

  shared_context 'base group template models' do
    let(:parent_group) { create(:group) }
    let(:subgroup) { create(:group, :public, parent: parent_group) }
    let(:group) { subgroup }
    let!(:project) { create(:project, :public, namespace: subgroup) }
    let(:new_project_name) { "project-#{SecureRandom.hex}" }
  end

  shared_context 'group template name' do
    include_context 'base group template models'

    let(:project_params) do
      {
        template_name: project.name,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        group_with_project_templates_id: subgroup.id,
        namespace_id: subgroup.id
      }
    end
  end

  shared_context 'group template ID' do
    include_context 'base group template models'

    let(:project_params) do
      {
        template_project_id: project.id,
        name: new_project_name,
        path: new_project_name,
        use_custom_template: true,
        group_with_project_templates_id: subgroup.id,
        namespace_id: subgroup.id
      }
    end
  end

  describe 'POST /projects/user/:id' do
    let(:admin) { create(:admin) }
    let(:api_call) { post api("/projects/user/#{user.id}", admin), params: project_params }

    context 'with templates' do
      include_context 'instance template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'instance template ID' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template ID' do
        it_behaves_like 'creates projects with templates'
      end
    end
  end

  describe 'POST /projects' do
    let(:api_call) { post api('/projects', user), params: project_params }

    context 'with templates' do
      include_context 'instance template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'instance template ID' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template name' do
        it_behaves_like 'creates projects with templates'
      end

      include_context 'group template ID' do
        it_behaves_like 'creates projects with templates'
      end
    end

    context 'when importing with mirror attributes' do
      let(:import_url) { generate(:url) }
      let(:mirror_params) do
        {
          name: "Foo",
          mirror: true,
          import_url: import_url,
          mirror_trigger_builds: true
        }
      end

      it 'creates new project with pull mirroring set up' do
        post api('/projects', user), params: mirror_params

        expect(response).to have_gitlab_http_status(:created)
        expect(Project.first).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true
        )
      end

      it 'creates project without mirror settings when repository mirroring feature is disabled' do
        stub_licensed_features(repository_mirrors: false)

        expect { post api('/projects', user), params: mirror_params }
          .to change { Project.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(Project.first).to have_attributes(
          mirror: false,
          import_url: import_url,
          mirror_user_id: nil,
          mirror_trigger_builds: false
        )
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'ignores the mirroring options' do
          post api('/projects', user), params: mirror_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.first.mirror?).to be false
        end

        it 'creates project with mirror settings' do
          admin = create(:admin)

          post api('/projects', admin), params: mirror_params

          expect(response).to have_gitlab_http_status(:created)
          expect(Project.first).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: admin.id,
            mirror_trigger_builds: true
          )
        end
      end
    end
  end

  describe 'PUT /projects/:id' do
    let(:project) { create(:project, namespace: user.namespace) }

    context 'when updating external classification' do
      before do
        enable_external_authorization_service_check
        stub_licensed_features(external_authorization_service_api_management: true)
      end

      it 'updates the classification label' do
        put(api("/projects/#{project.id}", user), params: { external_authorization_classification_label: 'new label' })

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload.external_authorization_classification_label).to eq('new label')
      end
    end

    context 'when updating service desk' do
      subject { put(api("/projects/#{project.id}", user), params: { service_desk_enabled: true }) }

      before do
        stub_licensed_features(service_desk: true)
        project.update!(service_desk_enabled: false)

        allow(::Gitlab::IncomingEmail).to receive(:enabled?).and_return(true)
      end

      it 'returns 200' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'enables the service_desk' do
        expect { subject }.to change { project.reload.service_desk_enabled }.to(true)
      end
    end

    context 'when updating mirror related attributes' do
      let(:import_url) { generate(:url) }
      let(:mirror_params) do
        {
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        }
      end

      context 'when pull mirroring is not available' do
        before do
          stub_ee_application_setting(mirror_available: false)
        end

        it 'does not update mirror related attributes' do
          put(api("/projects/#{project.id}", user), params: mirror_params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.mirror).to be false
        end

        it 'updates mirror related attributes when user is admin' do
          admin = create(:admin)
          mirror_params[:mirror_user_id] = admin.id
          project.add_maintainer(admin)

          expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

          put(api("/projects/#{project.id}", admin), params: mirror_params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload).to have_attributes(
            mirror: true,
            import_url: import_url,
            mirror_user_id: admin.id,
            mirror_trigger_builds: true,
            only_mirror_protected_branches: true,
            mirror_overwrites_diverged_branches: true
          )
        end
      end

      it 'updates mirror related attributes' do
        expect_any_instance_of(EE::ProjectImportState).to receive(:force_import_job!).once

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload).to have_attributes(
          mirror: true,
          import_url: import_url,
          mirror_user_id: user.id,
          mirror_trigger_builds: true,
          only_mirror_protected_branches: true,
          mirror_overwrites_diverged_branches: true
        )
      end

      it 'updates project without mirror attributes when the project is unable to set up repository mirroring' do
        stub_licensed_features(repository_mirrors: false)

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload.mirror).to be false
      end

      it 'renders an API error when mirror user is invalid' do
        invalid_mirror_user = create(:user)
        project.add_developer(invalid_mirror_user)
        mirror_params[:mirror_user_id] = invalid_mirror_user.id

        put(api("/projects/#{project.id}", user), params: mirror_params)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]["mirror_user_id"].first).to eq("is invalid")
      end

      it 'returns 403 when the user does not have access to mirror settings' do
        developer = create(:user)
        project.add_developer(developer)

        put(api("/projects/#{project.id}", developer), params: mirror_params)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    describe 'updating packages_enabled attribute' do
      it 'is enabled by default' do
        expect(project.packages_enabled).to be true
      end

      context 'packages feature is allowed by license' do
        before do
          stub_licensed_features(packages: true)
        end

        it 'disables project packages feature' do
          put(api("/projects/#{project.id}", user), params: { packages_enabled: false })

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.packages_enabled).to be false
          expect(json_response['packages_enabled']).to eq(false)
        end
      end

      context 'packages feature is not allowed by license' do
        before do
          stub_licensed_features(packages: false)
        end

        it 'disables project packages feature but does not return packages_enabled attribute' do
          put(api("/projects/#{project.id}", user), params: { packages_enabled: false })

          expect(response).to have_gitlab_http_status(:ok)
          expect(project.reload.packages_enabled).to be false
          expect(json_response['packages_enabled']).to be_nil
        end
      end
    end

    describe 'updating approvals_before_merge attribute' do
      context 'when authenticated as project owner' do
        it 'updates approvals_before_merge' do
          project_param = { approvals_before_merge: 3 }

          put api("/projects/#{project.id}", user), params: project_param

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['approvals_before_merge']).to eq(3)
        end
      end
    end
  end

  describe 'POST /projects/:id/restore' do
    context 'feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      it 'restores project' do
        project.update(archived: true, marked_for_deletion_at: 1.day.ago, deleting_user: user)

        post api("/projects/#{project.id}/restore", user)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['archived']).to be_falsey
        expect(json_response['marked_for_deletion_at']).to be_falsey
      end

      it 'returns error if project is already being deleted' do
        message = 'Error'
        expect(::Projects::RestoreService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: message })

        post api("/projects/#{project.id}/restore", user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]).to eq(message)
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it 'returns error' do
        post api("/projects/#{project.id}/restore", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /projects/:id' do
    context 'when feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      it 'marks project for deletion' do
        delete api("/projects/#{project.id}", user)

        expect(response).to have_gitlab_http_status(:accepted)
        expect(project.reload.marked_for_deletion?).to be_truthy
      end

      it 'returns error if project cannot be marked for deletion' do
        message = 'Error'
        expect(::Projects::MarkForDeletionService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: message })

        delete api("/projects/#{project.id}", user)

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response["message"]).to eq(message)
      end

      context 'when instance setting is set to 0 days' do
        it 'deletes project right away' do
          allow(Gitlab::CurrentSettings).to receive(:deletion_adjourned_period).and_return(0)
          delete api("/projects/#{project.id}", user)

          expect(response).to have_gitlab_http_status(:accepted)
          expect(project.reload.pending_delete).to eq(true)
        end
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it 'deletes project' do
        delete api("/projects/#{project.id}", user)

        expect(response).to have_gitlab_http_status(:accepted)
        expect(project.reload.pending_delete).to eq(true)
      end
    end
  end

  describe 'POST /projects/:id/fork' do
    subject(:fork_call) { post api("/projects/#{group_project.id}/fork", user), params: { namespace: target_namespace.id } }

    let!(:target_namespace) do
      create(:group).tap { |g| g.add_owner(user) }
    end
    let!(:group_project) { create(:project, namespace: group)}
    let(:group) { create(:group) }

    before do
      group.add_reporter(user)
    end

    context 'when project namespace has prohibit_outer_forks enabled' do
      let(:group) do
        create(:saml_provider, :enforced_group_managed_accounts, prohibited_outer_forks: true).group
      end
      let(:user) do
        create(:user, managing_group: group).tap do |u|
          create(:group_saml_identity, user: u, saml_provider: group.saml_provider)
        end
      end

      before do
        stub_feature_flags(enforced_sso_requires_session: false)
        stub_licensed_features(group_saml: true)
      end

      context 'and target namespace is outer' do
        it 'renders 404' do
          expect { fork_call }.not_to change { ::Project.count }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq "404 Target Namespace Not Found"
        end
      end

      context 'and target namespace is inner to project namespace' do
        let!(:target_namespace) { create(:group, parent: group) }

        it 'forks the project' do
          target_namespace.add_owner(user)

          expect { fork_call }.to change { ::Project.count }.by(1)
        end
      end
    end
  end
end
