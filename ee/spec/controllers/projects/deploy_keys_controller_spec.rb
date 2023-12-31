# frozen_string_literal: true

require 'spec_helper'

describe Projects::DeployKeysController do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)

    sign_in(user)
  end

  describe 'POST create' do
    let(:deploy_key_attrs) { attributes_for(:deploy_key) }
    let(:title) { 'my-key' }
    let(:params) do
      {
        namespace_id: project.namespace.path,
        project_id: project.path,
        deploy_key: {
          title: title,
          key: deploy_key_attrs[:key],
          deploy_keys_projects_attributes: { '0' => { can_push: '1' } }
        }
      }
    end

    it 'records an audit event' do
      expect { post :create, params: params }.to change { AuditEvent.count }.by(1)

      expect(response).to redirect_to(project_settings_ci_cd_path(project, anchor: 'js-deploy-keys-settings'))
    end
  end

  describe '/enable/:id' do
    let(:deploy_key) { create(:deploy_key) }
    let(:project2) { create(:project) }
    let!(:deploy_keys_project_internal) do
      create(:deploy_keys_project, project: project2, deploy_key: deploy_key)
    end

    context 'with user with permission' do
      before do
        project2.add_maintainer(user)
      end

      it 'records an audit event' do
        expect do
          put :enable, params: { id: deploy_key.id, namespace_id: project.namespace, project_id: project }
        end.to change { AuditEvent.count }.by(1)
      end

      it 'returns 404' do
        put :enable, params: { id: 0, namespace_id: project.namespace, project_id: project }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '/disable/:id' do
    let(:deploy_key) { create(:deploy_key) }
    let!(:deploy_key_project) { create(:deploy_keys_project, project: project, deploy_key: deploy_key) }

    context 'with admin' do
      before do
        sign_in(create(:admin))
      end

      it 'records an audit event' do
        expect do
          put :disable, params: { id: deploy_key.id, namespace_id: project.namespace, project_id: project }
        end.to change { AuditEvent.count }.by(1)
      end
    end
  end
end
