# frozen_string_literal: true

require 'spec_helper'

describe API::Geo do
  include TermsHelper
  include ApiHelpers
  include ::EE::GeoHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:primary_node) { create(:geo_node, :primary) }
  let_it_be(:secondary_node) { create(:geo_node) }
  let(:geo_token_header) do
    { 'X-Gitlab-Token' => secondary_node.system_hook.token }
  end

  let(:not_found_req_header) do
    Gitlab::Geo::TransferRequest.new(transfer.request_data.merge(file_id: 100000)).headers
  end

  before do
    stub_current_geo_node(primary_node)
  end

  shared_examples 'with terms enforced' do
    before do
      enforce_terms
    end

    it 'responds with 2xx HTTP response code' do
      request

      expect(response).to have_gitlab_http_status(:success)
    end
  end

  describe 'GET /geo/transfers' do
    before do
      stub_current_geo_node(secondary_node)
    end

    describe 'allowed IPs' do
      let(:note) { create(:note, :with_attachment) }
      let(:upload) { Upload.find_by(model: note, uploader: 'AttachmentUploader') }
      let(:transfer) { Gitlab::Geo::Replication::FileTransfer.new(:attachment, upload) }
      let(:req_header) { Gitlab::Geo::TransferRequest.new(transfer.request_data).headers }

      it 'responds with 401 when IP is not allowed' do
        stub_application_setting(geo_node_allowed_ips: '192.34.34.34')

        get api("/geo/transfers/attachment/#{upload.id}"), headers: req_header

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'responds with 200 when IP is allowed' do
        stub_application_setting(geo_node_allowed_ips: '127.0.0.1')

        get api("/geo/transfers/attachment/#{upload.id}"), headers: req_header

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'GET /geo/transfers/attachment/:id' do
      let(:note) { create(:note, :with_attachment) }
      let(:upload) { Upload.find_by(model: note, uploader: 'AttachmentUploader') }
      let(:transfer) { Gitlab::Geo::Replication::FileTransfer.new(:attachment, upload) }
      let(:req_header) { Gitlab::Geo::TransferRequest.new(transfer.request_data).headers }

      before do
        allow_next_instance_of(Gitlab::Geo::TransferRequest) do |instance|
          allow(instance).to receive(:requesting_node).and_return(secondary_node)
        end
      end

      it 'responds with 401 with invalid auth header' do
        get api("/geo/transfers/attachment/#{upload.id}"), headers: { Authorization: 'Test' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'when attachment file exists' do
        subject(:request) { get api("/geo/transfers/attachment/#{upload.id}"), headers: req_header }

        it 'responds with 200 with X-Sendfile' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/octet-stream')
          expect(response.headers['X-Sendfile']).to eq(note.attachment.path)
        end

        it_behaves_like 'with terms enforced'
      end

      context 'when attachment does not exist' do
        it 'responds with 404' do
          get api("/geo/transfers/attachment/100000"), headers: not_found_req_header

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when attachment has mount_point nil' do
        it 'responds with 200 with X-Sendfile' do
          upload.update(mount_point: nil)

          get api("/geo/transfers/attachment/#{upload.id}"), headers: req_header

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/octet-stream')
          expect(response.headers['X-Sendfile']).to eq(note.attachment.path)
        end
      end
    end

    describe 'GET /geo/transfers/avatar/1' do
      let(:user) { create(:user, avatar: fixture_file_upload('spec/fixtures/dk.png', 'image/png')) }
      let(:upload) { Upload.find_by(model: user, uploader: 'AvatarUploader') }
      let(:transfer) { Gitlab::Geo::Replication::FileTransfer.new(:avatar, upload) }
      let(:req_header) { Gitlab::Geo::TransferRequest.new(transfer.request_data).headers }

      before do
        allow_next_instance_of(Gitlab::Geo::TransferRequest) do |instance|
          allow(instance).to receive(:requesting_node).and_return(secondary_node)
        end
      end

      it 'responds with 401 with invalid auth header' do
        get api("/geo/transfers/avatar/#{upload.id}"), headers: { Authorization: 'Test' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'avatar file exists' do
        subject(:request) { get api("/geo/transfers/avatar/#{upload.id}"), headers: req_header }

        it 'responds with 200 with X-Sendfile' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/octet-stream')
          expect(response.headers['X-Sendfile']).to eq(user.avatar.path)
        end

        it_behaves_like 'with terms enforced'
      end

      context 'avatar does not exist' do
        it 'responds with 404' do
          get api("/geo/transfers/avatar/100000"), headers: not_found_req_header

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'avatar has mount_point nil' do
        it 'responds with 200 with X-Sendfile' do
          upload.update(mount_point: nil)

          get api("/geo/transfers/avatar/#{upload.id}"), headers: req_header

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/octet-stream')
          expect(response.headers['X-Sendfile']).to eq(user.avatar.path)
        end
      end
    end

    describe 'GET /geo/transfers/file/1' do
      let(:project) { create(:project) }
      let(:upload) { Upload.find_by(model: project, uploader: 'FileUploader') }
      let(:transfer) { Gitlab::Geo::Replication::FileTransfer.new(:file, upload) }
      let(:req_header) { Gitlab::Geo::TransferRequest.new(transfer.request_data).headers }

      before do
        allow_next_instance_of(Gitlab::Geo::TransferRequest) do |instance|
          allow(instance).to receive(:requesting_node).and_return(secondary_node)
        end
        FileUploader.new(project).store!(fixture_file_upload('spec/fixtures/dk.png', 'image/png'))
      end

      it 'responds with 401 with invalid auth header' do
        get api("/geo/transfers/file/#{upload.id}"), headers: { Authorization: 'Test' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'when the Upload record exists' do
        context 'when the file exists' do
          subject(:request) { get api("/geo/transfers/file/#{upload.id}"), headers: req_header }

          it 'responds with 200 with X-Sendfile' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/octet-stream')
            expect(response.headers['X-Sendfile']).to end_with('dk.png')
          end

          it_behaves_like 'with terms enforced'
        end

        context 'file does not exist' do
          it 'responds with 404 and a specific geo code' do
            File.unlink(upload.absolute_path)

            get api("/geo/transfers/file/#{upload.id}"), headers: req_header

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['geo_code']).to eq(Gitlab::Geo::Replication::FILE_NOT_FOUND_GEO_CODE)
          end
        end
      end

      context 'when the Upload record does not exist' do
        it 'responds with 404' do
          get api("/geo/transfers/file/100000"), headers: not_found_req_header

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    describe 'GET /geo/transfers/lfs/1' do
      let(:lfs_object) { create(:lfs_object, :with_file) }
      let(:transfer) { Gitlab::Geo::Replication::LfsTransfer.new(lfs_object) }
      let(:req_header) { Gitlab::Geo::TransferRequest.new(transfer.request_data).headers }

      before do
        allow_next_instance_of(Gitlab::Geo::TransferRequest) do |instance|
          allow(instance).to receive(:requesting_node).and_return(secondary_node)
        end
      end

      it 'responds with 401 with invalid auth header' do
        get api("/geo/transfers/lfs/#{lfs_object.id}"), headers: { Authorization: 'Test' }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      context 'LFS object exists' do
        context 'file exists' do
          subject(:request) { get api("/geo/transfers/lfs/#{lfs_object.id}"), headers: req_header }

          it 'responds with 200 with X-Sendfile' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(response.headers['Content-Type']).to eq('application/octet-stream')
            expect(response.headers['X-Sendfile']).to eq(lfs_object.file.path)
          end

          it_behaves_like 'with terms enforced'
        end

        context 'file does not exist' do
          it 'responds with 404 and a specific geo code' do
            File.unlink(lfs_object.file.path)

            get api("/geo/transfers/lfs/#{lfs_object.id}"), headers: req_header

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['geo_code']).to eq(Gitlab::Geo::Replication::FILE_NOT_FOUND_GEO_CODE)
          end
        end
      end

      context 'LFS object does not exist' do
        it 'responds with 404' do
          get api("/geo/transfers/lfs/100000"), headers: not_found_req_header

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST /geo/status' do
    let(:geo_base_request) { Gitlab::Geo::BaseRequest.new(scope: ::Gitlab::Geo::API_SCOPE) }

    let(:data) do
      {
        geo_node_id: secondary_node.id,
        status_message: nil,
        db_replication_lag_seconds: 0,
        projects_count: 10,
        repositories_synced_count: 1,
        repositories_failed_count: 2,
        wikis_synced_count: 2,
        wikis_failed_count: 3,
        lfs_objects_count: 100,
        lfs_objects_synced_count: 50,
        lfs_objects_failed_count: 12,
        lfs_objects_synced_missing_on_primary_count: 4,
        job_artifacts_count: 100,
        job_artifacts_synced_count: 50,
        job_artifacts_failed_count: 12,
        job_artifacts_synced_missing_on_primary_count: 5,
        container_repositories_count: 100,
        container_repositories_synced_count: 50,
        container_repositories_failed_count: 12,
        design_repositories_count: 100,
        design_repositories_synced_count: 50,
        design_repositories_failed_count: 12,
        attachments_count: 30,
        attachments_synced_count: 30,
        attachments_failed_count: 25,
        attachments_synced_missing_on_primary_count: 6,
        last_event_id: 2,
        last_event_date: Time.now.utc,
        cursor_last_event_id: 1,
        cursor_last_event_date: Time.now.utc,
        event_log_max_id: 555,
        repository_created_max_id: 43,
        repository_updated_max_id: 132,
        repository_deleted_max_id: 23,
        repository_renamed_max_id: 11,
        repositories_changed_max_id: 109
      }
    end

    subject(:request) { post api('/geo/status'), params: data, headers: geo_base_request.headers }

    it 'responds with 401 with invalid auth header' do
      post api('/geo/status'), headers: { Authorization: 'Test' }

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    it 'responds with 401 when the db_key_base is wrong' do
      allow_next_instance_of(Gitlab::Geo::JwtRequestDecoder) do |instance|
        allow(instance).to receive(:decode).and_raise(Gitlab::Geo::InvalidDecryptionKeyError)
      end

      request

      expect(response).to have_gitlab_http_status(:unauthorized)
    end

    describe 'allowed IPs' do
      it 'responds with 401 when IP is not allowed' do
        stub_application_setting(geo_node_allowed_ips: '192.34.34.34')

        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'responds with 201 when IP is allowed' do
        stub_application_setting(geo_node_allowed_ips: '127.0.0.1')

        request

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when requesting primary node with valid auth header' do
      before do
        stub_current_geo_node(primary_node)
        allow(geo_base_request).to receive(:requesting_node) { secondary_node }
      end

      it 'updates the status and responds with 201' do
        expect { request }.to change { GeoNodeStatus.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(secondary_node.reload.status.projects_count).to eq(10)
      end

      it 'ignores invalid attributes upon update' do
        GeoNodeStatus.create(data)
        data.merge!(
          {
            'id' => nil,
            'test' => 'something'
          }
        )

        post api('/geo/status'), params: data, headers: geo_base_request.headers

        expect(response).to have_gitlab_http_status(:created)
      end

      it_behaves_like 'with terms enforced'
    end
  end

  describe '/geo/proxy_git_push_ssh' do
    let(:secret_token) { Gitlab::Shell.secret_token }
    let(:primary_repo) { 'http://localhost:3001/testuser/repo.git' }
    let(:data) { { primary_repo: primary_repo, gl_id: 'key-1', gl_username: 'testuser' } }

    before do
      stub_current_geo_node(secondary_node)
    end

    describe 'POST /geo/proxy_git_push_ssh/info_refs' do
      context 'with all required params missing' do
        it 'responds with 400' do
          post api('/geo/proxy_git_push_ssh/info_refs'), params: nil

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eql('secret_token is missing, data is missing, data[gl_id] is missing, data[primary_repo] is missing')
        end
      end

      context 'with all required params' do
        let(:git_push_ssh_proxy) { double(Gitlab::Geo::GitPushSSHProxy) }

        before do
          allow(Gitlab::Geo::GitPushSSHProxy).to receive(:new).with(data).and_return(git_push_ssh_proxy)
        end

        context 'with an invalid secret_token' do
          it 'responds with 401' do
            post(api('/geo/proxy_git_push_ssh/info_refs'), params: { secret_token: 'invalid', data: data })

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to be_nil
          end
        end

        context 'where an exception occurs' do
          it 'responds with 500' do
            expect(git_push_ssh_proxy).to receive(:info_refs).and_raise('deliberate exception raised')

            post api('/geo/proxy_git_push_ssh/info_refs'), params: { secret_token: secret_token, data: data }

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response['message']).to include('RuntimeError (deliberate exception raised)')
            expect(json_response['result']).to be_nil
          end
        end

        context 'with a valid secret token' do
          let(:http_response) { double(Net::HTTPOK, code: 200, body: 'something here') }
          let(:api_response) { Gitlab::Geo::GitPushSSHProxy::APIResponse.from_http_response(http_response, primary_repo) }

          before do
            # Mocking a real Net::HTTPSuccess is very difficult as it's not
            # easy to instantiate the class due to the way it sets the body
            expect(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          end

          it 'responds with 200' do
            expect(git_push_ssh_proxy).to receive(:info_refs).and_return(api_response)

            post api('/geo/proxy_git_push_ssh/info_refs'), params: { secret_token: secret_token, data: data }

            expect(response).to have_gitlab_http_status(:ok)
            expect(Base64.decode64(json_response['result'])).to eql('something here')
          end
        end
      end
    end

    describe 'POST /geo/proxy_git_push_ssh/push' do
      context 'with all required params missing' do
        it 'responds with 400' do
          post api('/geo/proxy_git_push_ssh/push'), params: nil

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eql('secret_token is missing, data is missing, data[gl_id] is missing, data[primary_repo] is missing, output is missing')
        end
      end

      context 'with all required params' do
        let(:output) { Base64.encode64('info_refs content') }
        let(:git_push_ssh_proxy) { double(Gitlab::Geo::GitPushSSHProxy) }

        before do
          allow(Gitlab::Geo::GitPushSSHProxy).to receive(:new).with(data).and_return(git_push_ssh_proxy)
        end

        context 'with an invalid secret_token' do
          it 'responds with 401' do
            post(api('/geo/proxy_git_push_ssh/push'), params: { secret_token: 'invalid', data: data, output: output })

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['error']).to be_nil
          end
        end

        context 'where an exception occurs' do
          it 'responds with 500' do
            expect(git_push_ssh_proxy).to receive(:push).and_raise('deliberate exception raised')
            post api('/geo/proxy_git_push_ssh/push'), params: { secret_token: secret_token, data: data, output: output }

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response['message']).to include('RuntimeError (deliberate exception raised)')
            expect(json_response['result']).to be_nil
          end
        end

        context 'with a valid secret token' do
          let(:http_response) { double(Net::HTTPCreated, code: 201, body: 'something here', class: Net::HTTPCreated) }
          let(:api_response) { Gitlab::Geo::GitPushSSHProxy::APIResponse.from_http_response(http_response, primary_repo) }

          before do
            # Mocking a real Net::HTTPSuccess is very difficult as it's not
            # easy to instantiate the class due to the way it sets the body
            expect(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          end

          it 'responds with 201' do
            expect(git_push_ssh_proxy).to receive(:push).with(output).and_return(api_response)

            post api('/geo/proxy_git_push_ssh/push'), params: { secret_token: secret_token, data: data, output: output }

            expect(response).to have_gitlab_http_status(:created)
            expect(Base64.decode64(json_response['result'])).to eql('something here')
          end
        end
      end
    end
  end
end
