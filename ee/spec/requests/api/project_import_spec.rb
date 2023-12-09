# frozen_string_literal: true

require 'spec_helper'

describe API::ProjectImport do
  include ExternalAuthorizationServiceHelpers
  include WorkhorseHelpers

  let(:user) { create(:user) }
  let(:namespace) { create(:group) }

  let(:file) { File.join('spec', 'features', 'projects', 'import_export', 'test_project_export.tar.gz') }
  let(:file_name) { 'project_export.tar.gz' }

  let(:workhorse_token) { JWT.encode({ 'iss' => 'gitlab-workhorse' }, Gitlab::Workhorse.secret, 'HS256') }
  let(:workhorse_headers) { { 'GitLab-Workhorse' => '1.0', Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER => workhorse_token } }

  let(:file_upload) { fixture_file_upload(file) }

  before do
    enable_external_authorization_service_check
    stub_licensed_features(external_authorization_service_api_management: true)

    namespace.add_owner(user)
  end

  describe 'POST /projects/import' do
    let(:params) do
      {
        path: 'test-import',
        namespace: namespace.id,
        override_params: override_params
      }
    end

    let(:override_params) { { 'external_authorization_classification_label' => 'Hello world' } }

    subject do
      Sidekiq::Testing.inline! do
        upload_archive(file_upload, workhorse_headers, params)
      end
    end

    it 'overrides the classification label' do
      subject

      import_project = Project.find(json_response['id'])
      expect(import_project.external_authorization_classification_label).to eq('Hello world')
    end

    context 'feature is disabled' do
      before do
        stub_licensed_features(external_authorization_service_api_management: false)
      end

      it 'uses the default the classification label and ignores override param' do
        subject

        import_project = Project.find(json_response['id'])
        expect(import_project.external_authorization_classification_label).to eq('default_label')
      end
    end
  end

  def upload_archive(file, headers = {}, params = {})
    workhorse_finalize(
      api("/projects/import", user),
      method: :post,
      file_key: :file,
      params: params.merge(file: file_upload),
      headers: headers,
      send_rewritten_field: true
    )
  end
end
