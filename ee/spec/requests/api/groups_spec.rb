# frozen_string_literal: true

require 'spec_helper'

describe API::Groups do
  include GroupAPIHelpers

  let_it_be(:group, reload: true) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }
  let(:admin) { create(:admin) }

  before do
    group.add_owner(user)
    group.ldap_group_links.create cn: 'ldap-group', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap'
  end

  describe "GET /groups" do
    context "when authenticated as user" do
      it "returns ldap details" do
        get api("/groups", user)

        expect(json_response).to(
          satisfy_one { |group_json| group_json['ldap_cn'] == group.ldap_cn })
        expect(json_response).to(
          satisfy_one do |group_json|
            group_json['ldap_access'] == group.ldap_access
          end
        )

        expect(json_response).to(
          satisfy_one do |group_json|
            ldap_group_link = group_json['ldap_group_links'].first

            ldap_group_link['cn'] == group.ldap_cn &&
              ldap_group_link['group_access'] == group.ldap_access &&
              ldap_group_link['provider'] == 'ldap'
          end
        )
      end
    end
  end

  describe 'GET /groups/:id' do
    context 'group_ip_restriction' do
      before do
        create(:ip_restriction, group: private_group)
        private_group.add_maintainer(user)
      end

      context 'when the group_ip_restriction feature is not available' do
        before do
          stub_licensed_features(group_ip_restriction: false)
        end

        it 'returns 200' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the group_ip_restriction feature is available' do
        before do
          stub_licensed_features(group_ip_restriction: true)
        end

        it 'returns 404 for request from ip not in the range' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 200 for request from ip in the range' do
          get api("/groups/#{private_group.id}", user), headers: { 'REMOTE_ADDR' => '192.168.0.0' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'marked_for_deletion_on attribute' do
      context 'when feature is available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        end

        it 'is exposed' do
          get api("/groups/#{group.id}", user)

          expect(json_response).to have_key 'marked_for_deletion_on'
        end
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        end

        it 'is not exposed' do
          get api("/groups/#{group.id}", user)

          expect(json_response).not_to have_key 'marked_for_deletion_on'
        end
      end
    end
  end

  describe 'PUT /groups/:id' do
    subject { put api("/groups/#{group.id}", user), params: params }

    context 'file_template_project_id' do
      let(:params) { { file_template_project_id: project.id } }

      it 'does not update file_template_project_id if unlicensed' do
        stub_licensed_features(custom_file_templates_for_namespace: false)

        expect { subject }.not_to change { group.reload.file_template_project_id }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key('file_template_project_id')
      end

      it 'updates file_template_project_id if licensed' do
        stub_licensed_features(custom_file_templates_for_namespace: true)

        expect { subject }.to change { group.reload.file_template_project_id }.to(project.id)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['file_template_project_id']).to eq(project.id)
      end
    end

    context 'shared_runners_minutes_limit' do
      let(:params) { { shared_runners_minutes_limit: 133 } }

      context 'when authenticated as the group owner' do
        it 'returns 200 if shared_runners_minutes_limit is not changing' do
          group.update(shared_runners_minutes_limit: 133)

          expect do
            put api("/groups/#{group.id}", user), params: { shared_runners_minutes_limit: 133 }
          end.not_to change { group.shared_runners_minutes_limit }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when authenticated as the admin' do
        let(:user) { create(:admin) }

        it 'updates the group for shared_runners_minutes_limit' do
          expect { subject }.to(
            change { group.reload.shared_runners_minutes_limit }.from(nil).to(133))

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(133)
        end
      end
    end
  end

  describe "POST /groups" do
    context "when authenticated as user with group permissions" do
      it "creates an ldap_group_link if ldap_cn and ldap_access are supplied" do
        group_attributes = attributes_for_group_api ldap_cn: 'ldap-group', ldap_access: Gitlab::Access::DEVELOPER
        expect { post api("/groups", admin), params: group_attributes }.to change { LdapGroupLink.count }.by(1)
      end

      context 'when shared_runners_minutes_limit is given' do
        context 'when the current user is not an admin' do
          it "does not create a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", another_user), params: group
            end.not_to change { Group.count }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when the current user is an admin' do
          it "creates a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", admin), params: group
            end.to change { Group.count }.by(1)

            created_group = Group.find(json_response['id'])

            expect(created_group.shared_runners_minutes_limit).to eq(133)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['shared_runners_minutes_limit']).to eq(133)
          end
        end
      end
    end
  end

  describe 'POST /groups/:id/ldap_sync' do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
    end

    context 'when the ldap_group_sync feature is available' do
      before do
        stub_licensed_features(ldap_group_sync: true)
      end

      context 'when authenticated as the group owner' do
        context 'when the group is ready to sync' do
          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'queues a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.to change(LdapGroupSyncWorker.jobs, :size).by(1)
          end

          it 'sets the ldap_sync state to pending' do
            ldap_sync(group.id, user, :disable!)
            expect(group.reload.ldap_sync_pending?).to be_truthy
          end
        end

        context 'when the group is already pending a sync' do
          before do
            group.pending_ldap_sync!
          end

          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'does not queue a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.not_to change(LdapGroupSyncWorker.jobs, :size)
          end

          it 'does not change the ldap_sync state' do
            expect do
              ldap_sync(group.id, user, :disable!)
            end.not_to change { group.reload.ldap_sync_status }
          end
        end

        it 'returns 404 for a non existing group' do
          non_existent_group_id = Group.maximum(:id).to_i + 1
          ldap_sync(non_existent_group_id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when authenticated as the admin' do
        it 'returns 202 Accepted' do
          ldap_sync(group.id, admin, :disable!)
          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'when authenticated as a non-owner user that can see the group' do
        it 'returns 403' do
          ldap_sync(group.id, another_user, :disable!)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an user that cannot see the group' do
        it 'returns 404' do
          ldap_sync(private_group.id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the ldap_group_sync feature is not available' do
      before do
        stub_licensed_features(ldap_group_sync: false)
      end

      it 'returns 404 (same as CE would)' do
        ldap_sync(group.id, admin, :disable!)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "GET /groups/:id/projects" do
    context "when authenticated as user" do
      let(:project_with_reports) { create(:project, :public, group: group) }
      let!(:project_without_reports) { create(:project, :public, group: group) }

      before do
        create(:ee_ci_job_artifact, :sast, project: project_with_reports)
      end

      subject { get api("/groups/#{group.id}/projects", user), params: { with_security_reports: true } }

      context 'when security dashboard is enabled for a group' do
        let(:group) { create(:group, plan: :gold_plan) } # overriding group from parent context

        before do
          stub_licensed_features(security_dashboard: true)
          enable_namespace_license_check!

          create(:gitlab_subscription, hosted_plan: group.plan, namespace: group)
        end

        it "returns only projects with security reports" do
          subject

          expect(json_response.map { |p| p['id'] }).to contain_exactly(project_with_reports.id)
        end
      end

      context 'when security dashboard is disabled for a group' do
        it "returns all projects regardless of the security reports" do
          subject

          # using `include` since other projects may be added to this group from different contexts
          expect(json_response.map { |p| p['id'] }).to include(project_with_reports.id, project_without_reports.id)
        end
      end
    end
  end

  describe 'GET group/:id/audit_events' do
    let(:path) { "/groups/#{group.id}/audit_events" }

    context 'when authenticated, as a user' do
      it_behaves_like '403 response' do
        let(:request) { get api(path, create(:user)) }
      end
    end

    context 'when authenticated, as a group owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        let_it_be(:group_audit_event_1) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }
        let_it_be(:group_audit_event_2) { create(:group_audit_event, created_at: Date.new(2000, 1, 15), entity_id: group.id) }
        let_it_be(:group_audit_event_3) { create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id) }

        before do
          stub_licensed_features(audit_events: true)
        end

        it 'returns 200 response' do
          get api(path, user)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'includes the correct pagination headers' do
          audit_events_counts = 3

          get api(path, user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
          expect(response.headers['X-Page']).to eq('1')
        end

        it 'does not include audit events of a different group' do
          group = create(:group)
          audit_event = create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id)

          get api(path, user)

          audit_event_ids = json_response.map { |audit_event| audit_event['id'] }

          expect(audit_event_ids).not_to include(audit_event.id)
        end

        context 'parameters' do
          context 'created_before parameter' do
            it "returns audit events created before the given parameter" do
              created_before = '2000-01-20T00:00:00.060Z'

              get api(path, user), params: { created_before: created_before }

              expect(json_response.size).to eq 3
              expect(json_response.first["id"]).to eq(group_audit_event_3.id)
              expect(json_response.last["id"]).to eq(group_audit_event_1.id)
            end
          end

          context 'created_after parameter' do
            it "returns audit events created after the given parameter" do
              created_after = '2000-01-12T00:00:00.060Z'

              get api(path, user), params: { created_after: created_after }

              expect(json_response.size).to eq 2
              expect(json_response.first["id"]).to eq(group_audit_event_3.id)
              expect(json_response.last["id"]).to eq(group_audit_event_2.id)
            end
          end
        end

        context 'response schema' do
          it 'matches the response schema' do
            get api(path, user)

            expect(response).to match_response_schema('public_api/v4/audit_events', dir: 'ee')
          end
        end
      end
    end
  end

  describe 'GET group/:id/audit_events/:audit_event_id' do
    let(:path) { "/groups/#{group.id}/audit_events/#{group_audit_event.id}" }

    let_it_be(:group_audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }

    context 'when authenticated, as a user' do
      it_behaves_like '403 response' do
        let(:request) { get api(path, create(:user)) }
      end
    end

    context 'when authenticated, as a group owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(audit_events: true)
        end

        context 'existent audit event' do
          it 'returns 200 response' do
            get api(path, user)

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'response schema' do
            it 'matches the response schema' do
              get api(path, user)

              expect(response).to match_response_schema('public_api/v4/audit_event', dir: 'ee')
            end
          end

          context 'invalid audit_event_id' do
            let(:path) { "/groups/#{group.id}/audit_events/an-invalid-id" }

            it_behaves_like '400 response' do
              let(:request) { get api(path, user) }
            end
          end

          context 'non existent audit event' do
            context 'non existent audit event of a group' do
              let(:path) { "/groups/#{group.id}/audit_events/666777" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end

            context 'existing audit event of a different group' do
              let(:new_group) { create(:group) }
              let(:audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: new_group.id) }

              let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end
          end
        end
      end
    end
  end

  describe "DELETE /groups/:id" do
    subject { delete api("/groups/#{group.id}", user) }

    shared_examples_for 'immediately enqueues the job to delete the group' do
      it do
        Sidekiq::Testing.fake! do
          expect { subject }.to change(GroupDestroyWorker.jobs, :size).by(1)
        end

        expect(response).to have_gitlab_http_status(:accepted)
      end
    end

    context 'feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'period for adjourned deletion is greater than 0' do
        before do
          stub_application_setting(deletion_adjourned_period: 1)
        end

        context 'success' do
          it 'marks the group for adjourned deletion' do
            subject
            group.reload

            expect(response).to have_gitlab_http_status(:accepted)
            expect(group.marked_for_deletion_on).to eq(Date.today)
            expect(group.deleting_user).to eq(user)
          end

          it 'does not immediately enqueue the job to delete the group' do
            expect { subject }.not_to change(GroupDestroyWorker.jobs, :size)
          end
        end

        context 'failure' do
          before do
            allow(::Groups::MarkForDeletionService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'returns error' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('error')
          end
        end
      end

      context 'period of adjourned deletion is set to 0' do
        before do
          stub_application_setting(deletion_adjourned_period: 0)
        end

        it_behaves_like 'immediately enqueues the job to delete the group'
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it_behaves_like 'immediately enqueues the job to delete the group'
    end
  end

  describe "POST /groups/:id/restore" do
    let(:group) do
      create(:group_with_deletion_schedule,
      marked_for_deletion_on: 1.day.ago,
      deleting_user: user)
    end

    subject { post api("/groups/#{group.id}/restore", user) }

    context 'feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'authenticated as owner' do
        context 'restoring is successful' do
          it 'restores the group to original state' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['marked_for_deletion_on']).to be_falsey
          end
        end

        context 'restoring fails' do
          before do
            allow(::Groups::RestoreService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'returns error' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('error')
          end
        end
      end

      context 'authenticated as user without access to the group' do
        subject { post api("/groups/#{group.id}/restore", another_user) }

        it 'returns 403' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  def ldap_sync(group_id, user, sidekiq_testing_method)
    Sidekiq::Testing.send(sidekiq_testing_method) do
      post api("/groups/#{group_id}/ldap_sync", user)
    end
  end
end
