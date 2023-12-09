# frozen_string_literal: true
require 'spec_helper'

describe API::Internal::Base do
  include EE::GeoHelpers

  let_it_be(:primary_node, reload: true) { create(:geo_node, :primary) }
  let_it_be(:secondary_node, reload: true) { create(:geo_node) }

  describe 'POST /internal/post_receive', :geo do
    let_it_be(:user) { create(:user) }
    let(:key) { create(:key, user: user) }
    let_it_be(:project, reload: true) { create(:project, :repository, :wiki_repo) }
    let(:secret_token) { Gitlab::Shell.secret_token }
    let(:gl_repository) { "project-#{project.id}" }
    let(:reference_counter) { double('ReferenceCounter') }

    let(:identifier) { 'key-123' }

    let(:valid_params) do
      {
        gl_repository: gl_repository,
        secret_token: secret_token,
        identifier: identifier,
        changes: changes,
        push_options: {}
      }
    end

    let(:branch_name) { 'feature' }

    let(:changes) do
      "#{Gitlab::Git::BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{branch_name}"
    end

    let(:git_push_http) { double('GitPushHttp') }

    before do
      project.add_developer(user)
      allow(described_class).to receive(:identify).and_return(user)
      allow_next_instance_of(Gitlab::Identifier) do |instance|
        allow(instance).to receive(:identify).and_return(user)
      end
      stub_current_geo_node(primary_node)
    end

    context 'when the push was redirected from a Geo secondary to the primary' do
      before do
        expect(Gitlab::Geo::GitPushHttp).to receive(:new).with(identifier, gl_repository).and_return(git_push_http)
        expect(git_push_http).to receive(:fetch_referrer_node).and_return(secondary_node)
      end

      context 'when the secondary has a GeoNodeStatus' do
        context 'when the GeoNodeStatus db_replication_lag_seconds is greater than 0' do
          let!(:status) { create(:geo_node_status, geo_node: secondary_node, db_replication_lag_seconds: 17) }

          it 'includes current Geo secondary lag in the output' do
            post api('/internal/post_receive'), params: valid_params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['messages']).to include({
              'type' => 'basic',
              'message' => "Current replication lag: 17 seconds"
            })
          end
        end

        context 'when the GeoNodeStatus db_replication_lag_seconds is 0' do
          let!(:status) { create(:geo_node_status, geo_node: secondary_node, db_replication_lag_seconds: 0) }

          it 'does not include current Geo secondary lag in the output' do
            post api('/internal/post_receive'), params: valid_params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['messages']).not_to include({ 'message' => a_string_matching('replication lag'), 'type' => anything })
          end
        end

        context 'when the GeoNodeStatus db_replication_lag_seconds is nil' do
          let!(:status) { create(:geo_node_status, geo_node: secondary_node, db_replication_lag_seconds: nil) }

          it 'does not include current Geo secondary lag in the output' do
            post api('/internal/post_receive'), params: valid_params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['messages']).not_to include({ 'message' => a_string_matching('replication lag'), 'type' => anything })
          end
        end
      end

      context 'when the secondary does not have a GeoNodeStatus' do
        it 'does not include current Geo secondary lag in the output' do
          post api('/internal/post_receive'), params: valid_params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['messages']).not_to include({ 'message' => a_string_matching('replication lag'), 'type' => anything })
        end
      end
    end

    context 'when the push was not redirected from a Geo secondary to the primary' do
      before do
        expect(Gitlab::Geo::GitPushHttp).to receive(:new).with(identifier, gl_repository).and_return(git_push_http)
        expect(git_push_http).to receive(:fetch_referrer_node).and_return(nil)
      end

      it 'does not include current Geo secondary lag in the output' do
        post api('/internal/post_receive'), params: valid_params

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['messages']).not_to include({ 'message' => a_string_matching('replication lag'), 'type' => anything })
      end
    end
  end

  describe "POST /internal/allowed" do
    let_it_be(:user) { create(:user) }
    let_it_be(:key) { create(:key, user: user) }
    let(:secret_token) { Gitlab::Shell.secret_token }

    context "for design repositories" do
      let_it_be(:project) { create(:project) }
      let(:gl_repository) { EE::Gitlab::GlRepository::DESIGN.identifier_for_container(project) }

      it "does not allow access" do
        post(api("/internal/allowed"),
             params: {
               key_id: key.id,
               project: project.full_path,
               gl_repository: gl_repository,
               secret_token: secret_token,
               protocol: 'ssh'
             })

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "project alias" do
      let(:project) { create(:project, :public, :repository) }
      let(:project_alias) { create(:project_alias, project: project) }

      def check_access_by_alias(alias_name)
        post(
          api("/internal/allowed"),
          params: {
            action: "git-upload-pack",
            key_id: key.id,
            project: alias_name,
            protocol: 'ssh',
            secret_token: secret_token
          }
        )
      end

      context "without premium license" do
        context "project matches a project alias" do
          before do
            check_access_by_alias(project_alias.name)
          end

          it "does not allow access because project can't be found" do
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context "with premium license" do
        before do
          stub_licensed_features(project_aliases: true)
        end

        context "project matches a project alias" do
          before do
            check_access_by_alias(project_alias.name)
          end

          it "allows access" do
            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context "project doesn't match a project alias" do
          before do
            check_access_by_alias('some-project')
          end

          it "does not allow access because project can't be found" do
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    context 'smartcard session required' do
      let_it_be(:project) { create(:project, :repository, :wiki_repo) }

      subject do
        post(
          api("/internal/allowed"),
          params: { key_id: key.id,
                    project: project.full_path,
                    gl_repository: "project-#{project.id}",
                    action: 'git-upload-pack',
                    secret_token: secret_token,
                    protocol: 'ssh' })
      end

      before do
        stub_licensed_features(smartcard_auth: true)
        stub_smartcard_setting(enabled: true, required_for_git_access: true)

        project.add_developer(user)
      end

      context 'user with a smartcard session', :clean_gitlab_redis_shared_state do
        let(:session_id) { '42' }
        let(:stored_session) do
          { 'smartcard_signins' => { 'last_signin_at' => 5.minutes.ago } }
        end

        before do
          Gitlab::Redis::SharedState.with do |redis|
            redis.set("session:gitlab:#{session_id}", Marshal.dump(stored_session))
            redis.sadd("session:lookup:user:gitlab:#{user.id}", [session_id])
          end
        end

        it "allows access" do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'user without a smartcard session' do
        it "does not allow access" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response['message']).to eql('Project requires smartcard login. Please login to GitLab using a smartcard.')
        end
      end

      context 'with the setting off' do
        before do
          stub_smartcard_setting(required_for_git_access: false)
        end

        it "allows access" do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'ip restriction' do
      let_it_be(:group) { create(:group)}
      let_it_be(:project) { create(:project, :repository, namespace: group) }
      let(:params) do
        {
          key_id: key.id,
          project: project.full_path,
          gl_repository: "project-#{project.id}",
          action: 'git-upload-pack',
          secret_token: secret_token,
          protocol: 'ssh'
        }
      end
      let(:allowed_ip) { '150.168.0.1' }

      before do
        create(:ip_restriction, group: group, range: allowed_ip)
        stub_licensed_features(group_ip_restriction: true)

        project.add_developer(user)
      end

      context 'with or without check_ip parameter' do
        using RSpec::Parameterized::TableSyntax

        where(:check_ip_present, :ip, :status) do
          false | nil           | 200
          true  | '150.168.0.1' | 200
          true  | '150.168.0.2' | 404
        end

        with_them do
          subject do
            post(
              api('/internal/allowed'),
              params: check_ip_present ? params.merge(check_ip: ip) : params
            )
          end

          it 'modifies access' do
            subject

            expect(response).to have_gitlab_http_status(status)
          end
        end
      end
    end
  end

  describe "POST /internal/lfs_authenticate", :geo do
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository) }
    let(:secret_token) { Gitlab::Shell.secret_token }

    context 'for a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
        project.add_developer(user)
      end

      it 'returns the repository_http_path at the primary node' do
        expect(Project).to receive(:find_by_full_path).and_return(project)

        lfs_auth_user(user.id, project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['repository_http_path']).to eq(geo_primary_http_url_to_repo(project))
      end
    end

    def lfs_auth_user(user_id, project)
      post(
        api("/internal/lfs_authenticate"),
        params: {
          user_id: user_id,
          secret_token: secret_token,
          project: project.full_path
        }
      )
    end
  end
end
