# frozen_string_literal: true

require 'spec_helper'

describe API::Scim do
  let(:user) { create(:user) }
  let(:scim_token) { create(:scim_oauth_access_token, group: group) }

  before do
    stub_licensed_features(group_allowed_email_domains: true, group_saml: true)

    group.add_owner(user)
  end

  def scim_api(url, token: true)
    api(url, user, version: '', oauth_access_token: token ? scim_token : nil)
  end

  shared_examples 'SCIM token authenticated' do
    context 'without token auth' do
      it 'responds with 401' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"#{identity.extern_uid}\"", token: false)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  shared_examples 'SCIM API endpoints' do
    describe 'GET api/scim/v2/groups/:group/Users' do
      it_behaves_like 'SCIM token authenticated'

      it 'responds with paginated users when there is no filter' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['Resources']).not_to be_empty
      end

      it 'responds with an error for unsupported filters' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id ne \"#{identity.extern_uid}\"")

        expect(response).to have_gitlab_http_status(:precondition_failed)
      end

      context 'existing user matches filter' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"#{identity.extern_uid}\"")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).not_to be_empty
          expect(json_response['totalResults']).to eq(1)
        end

        it 'sets default values as required by the specification' do
          get scim_api(%{scim/v2/groups/#{group.full_path}/Users?filter=id eq "#{identity.extern_uid}"})

          expect(json_response['schemas']).to eq(['urn:ietf:params:scim:api:messages:2.0:ListResponse'])
          expect(json_response['itemsPerPage']).to eq(20)
          expect(json_response['startIndex']).to eq(1)
        end
      end

      context 'no user matches filter' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users?filter=id eq \"nonexistent\"")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['Resources']).to be_empty
          expect(json_response['totalResults']).to eq(0)
        end
      end
    end

    describe 'GET api/scim/v2/groups/:group/Users/:id' do
      it_behaves_like 'SCIM token authenticated'

      it 'responds with 404 if there is no user' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'existing user' do
        it 'responds with 200' do
          get scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['id']).to eq(identity.extern_uid)
        end
      end
    end

    describe 'POST api/scim/v2/groups/:group/Users' do
      it_behaves_like 'SCIM token authenticated'

      let_it_be(:post_params) do
        {
          externalId: 'test_uid',
          active: nil,
          userName: 'username',
          emails: [
            { primary: true, type: 'work', value: 'work@example.com' }
          ],
          name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' }
        }.to_query
      end

      context 'without an existing user' do
        let(:new_user) { User.find_by_email('work@example.com') }
        let(:member) { GroupMember.find_by(user: new_user, group: group) }

        before do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end

        it 'has the email' do
          expect(json_response['emails'].first['value']).to eq('work@example.com')
        end

        it 'created the user' do
          expect(new_user).not_to be_nil
        end

        it 'created the right member' do
          expect(member.access_level).to eq(::Gitlab::Access::GUEST)
        end
      end

      it_behaves_like 'storing arguments in the application context' do
        let(:expected_params) { { root_namespace: group.full_path_components.first } }

        subject { post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}") }
      end

      context 'with allowed domain setting switched on' do
        let(:new_user) { User.find_by_email('work@example.com') }
        let(:member) { GroupMember.find_by(user: new_user, group: group) }

        context 'with different domains' do
          before do
            create(:allowed_email_domain, group: group)
            post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
          end

          it 'created the user' do
            expect(new_user).not_to be_nil
          end

          it 'did not create member' do
            expect(member).to be_nil
          end

          context 'with invalid user params' do
            let(:post_params) do
              {
                externalId: 'test_uid',
                active: nil,
                userName: 'username',
                emails: [
                  { primary: nil, type: 'work', value: '' }
                ],
                name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' }
              }.to_query
            end

            it 'returns user error' do
              expect(response).to have_gitlab_http_status(:precondition_failed)
              expect(json_response.fetch('detail')).to include("Email can't be blank")
            end
          end
        end

        context 'with matching domains' do
          before do
            create(:allowed_email_domain, group: group, domain: 'example.com')
            post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
          end

          it 'created the user' do
            expect(new_user).not_to be_nil
          end

          it 'created the right member' do
            expect(member.access_level).to eq(::Gitlab::Access::GUEST)
          end
        end
      end
    end

    describe 'PATCH api/scim/v2/groups/:group/Users/:id' do
      it_behaves_like 'SCIM token authenticated'

      it 'responds with 404 if there is no user' do
        patch scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'existing user' do
        context 'extern UID' do
          before do
            params = { Operations: [{ 'op': 'Replace', 'path': 'id', 'value': 'new_uid' }] }.to_query

            patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
          end

          it 'responds with 204' do
            expect(response).to have_gitlab_http_status(:no_content)
          end

          it 'updates the extern_uid' do
            expect(identity.reload.extern_uid).to eq('new_uid')
          end
        end

        context 'name' do
          before do
            params = { Operations: [{ 'op': 'Replace', 'path': 'name.formatted', 'value': 'new_name' }] }.to_query

            patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
          end

          it 'responds with 204' do
            expect(response).to have_gitlab_http_status(:no_content)
          end

          it 'updates the name' do
            expect(user.reload.name).to eq('new_name')
          end

          it 'responds with an empty response' do
            expect(response.body).to eq('')
          end
        end

        context 'email' do
          context 'non existent email' do
            before do
              params = { Operations: [{ 'op': 'Replace', 'path': 'emails[type eq "work"].value', 'value': 'new@mail.com' }] }.to_query

              patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
            end

            it 'updates the email' do
              expect(user.reload.unconfirmed_email).to eq('new@mail.com')
            end

            it 'responds with 204' do
              expect(response).to have_gitlab_http_status(:no_content)
            end
          end

          context 'existent email' do
            before do
              create(:user, email: 'new@mail.com')

              params = { Operations: [{ 'op': 'Replace', 'path': 'emails[type eq "work"].value', 'value': 'new@mail.com' }] }.to_query

              patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
            end

            it 'does not update a duplicated email' do
              expect(user.reload.unconfirmed_email).not_to eq('new@mail.com')
            end

            it 'responds with 209' do
              expect(response).to have_gitlab_http_status(:conflict)
            end
          end
        end

        context 'Remove user' do
          before do
            params = { Operations: [{ 'op': 'Replace', 'path': 'active', 'value': 'False' }] }.to_query

            patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
          end

          it 'responds with 204' do
            expect(response).to have_gitlab_http_status(:no_content)
          end
        end
      end
    end

    describe 'DELETE /scim/v2/groups/:group/Users/:id' do
      context 'existing user' do
        before do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")
        end

        it 'responds with 204' do
          expect(response).to have_gitlab_http_status(:no_content)
        end

        it 'responds with an empty response' do
          expect(response.body).to eq('')
        end
      end

      it 'responds with 404 if there is no user' do
        delete scim_api("scim/v2/groups/#{group.full_path}/Users/123")

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'SCIM API endpoints with scim_identities disabled' do
    describe 'GET api/scim/v2/groups/:group/Users' do
      it 'responds with paginated users when there is no filter' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(json_response['totalResults']).to eq(Identity.count)
      end
    end

    describe 'POST api/scim/v2/groups/:group/Users' do
      let_it_be(:post_params) do
        {
          externalId: 'test_uid',
          active: nil,
          userName: 'username',
          emails: [{ primary: true, type: 'work', value: 'work@example.com' }],
          name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' }
        }.to_query
      end
      context 'without an existing user' do
        let(:new_user) { User.find_by_email('work@example.com') }
        let(:member) { GroupMember.find_by(user: new_user, group: group) }

        before do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'created the identity' do
          expect(Identity.find_by_extern_uid(:group_saml, 'test_uid')).not_to be_nil
        end

        it 'has the right saml provider' do
          identity = Identity.find_by_extern_uid(:group_saml, 'test_uid')

          expect(identity.saml_provider_id).to eq(group.saml_provider.id)
        end
      end

      context 'existing user' do
        before do
          old_user = create(:user, email: 'work@example.com')

          create(:group_saml_identity, user: old_user, extern_uid: 'test_uid')
          group.add_guest(old_user)

          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end
      end
    end

    describe 'PATCH api/scim/v2/groups/:group/Users/:id' do
      context 'Remove user' do
        it 'removes the identity link' do
          params = { Operations: [{ 'op': 'Replace', 'path': 'active', 'value': 'False' }] }.to_query

          patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")

          expect { identity.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    describe 'DELETE /scim/v2/groups/:group/Users/:id' do
      context 'existing user' do
        it 'removes the identity link' do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect { identity.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end

  shared_examples 'SCIM API endpoints with scim_identities enabled' do
    describe 'GET api/scim/v2/groups/:group/Users' do
      it 'responds with paginated users when there is no filter' do
        get scim_api("scim/v2/groups/#{group.full_path}/Users")

        expect(json_response['totalResults']).to eq(ScimIdentity.count)
      end
    end

    describe 'POST api/scim/v2/groups/:group/Users' do
      let_it_be(:post_params) do
        {
          externalId: 'test_uid',
          active: nil,
          userName: 'username',
          emails: [{ primary: true, type: 'work', value: 'work@example.com' }],
          name: { formatted: 'Test Name', familyName: 'Name', givenName: 'Test' }
        }.to_query
      end

      context 'without an existing user' do
        let(:new_user) { User.find_by_email('work@example.com') }
        let(:member) { GroupMember.find_by(user: new_user, group: group) }

        before do
          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'created the identity' do
          expect(group.scim_identities.with_extern_uid('test_uid').first).not_to be_nil
        end
      end

      context 'existing user' do
        before do
          old_user = create(:user, email: 'work@example.com')

          create(:scim_identity, user: old_user, group: group, extern_uid: 'test_uid')
          group.add_guest(old_user)

          post scim_api("scim/v2/groups/#{group.full_path}/Users?params=#{post_params}")
        end

        it 'responds with 201' do
          expect(response).to have_gitlab_http_status(:created)
        end

        it 'has the user external ID' do
          expect(json_response['id']).to eq('test_uid')
        end
      end
    end

    describe 'PATCH api/scim/v2/groups/:group/Users/:id' do
      def call_patch_api
        patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
      end

      context 'Remove user' do
        it 'deactivates the scim_identity' do
          params = { Operations: [{ 'op': 'Replace', 'path': 'active', 'value': 'False' }] }.to_query

          patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")

          expect(identity.reload.active).to be false
        end
      end

      context 'Reprovision user' do
        def call_patch_api
          patch scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}?#{params}")
        end
        let_it_be(:params) { { Operations: [{ 'op': 'Replace', 'path': 'active', 'value': 'true' }] }.to_query }

        it 'activates the scim_identity' do
          identity.update(active: false)

          call_patch_api

          expect(identity.reload.active).to be true
        end

        it 'does not call reprovision service when identity is already active' do
          expect(::EE::Gitlab::Scim::ReprovisionService).not_to receive(:new)
          expect(::Users::UpdateService).to receive(:new).and_call_original

          call_patch_api
        end
      end
    end

    describe 'DELETE /scim/v2/groups/:group/Users/:id' do
      context 'existing user' do
        it 'deactivates the identity' do
          delete scim_api("scim/v2/groups/#{group.full_path}/Users/#{identity.extern_uid}")

          expect(identity.reload.active).to be false
        end
      end
    end
  end

  context 'when scim_identities is disabled' do
    before do
      stub_feature_flags(scim_identities: false)
    end
    let(:group) { identity.saml_provider.group }

    context 'user with an alphanumeric extern_uid' do
      let(:identity) { create(:group_saml_identity, user: user, extern_uid: generate(:username)) }

      it_behaves_like 'SCIM API endpoints'
      it_behaves_like 'SCIM API endpoints with scim_identities disabled'
    end

    context 'user with an email extern_uid' do
      let(:identity) { create(:group_saml_identity, user: user, extern_uid: user.email) }

      it_behaves_like 'SCIM API endpoints'
      it_behaves_like 'SCIM API endpoints with scim_identities disabled'
    end
  end

  context 'when scim_identities is enabled' do
    before do
      stub_feature_flags(scim_identities: true)
      create(:saml_provider, group: group)
    end
    let(:group) { identity.group }

    context 'user with an alphanumeric extern_uid' do
      let(:identity) { create(:scim_identity, user: user, extern_uid: generate(:username)) }

      it_behaves_like 'SCIM API endpoints'
      it_behaves_like 'SCIM API endpoints with scim_identities enabled'
    end

    context 'user with an email extern_uid' do
      let(:identity) { create(:scim_identity, user: user, extern_uid: user.email) }

      it_behaves_like 'SCIM API endpoints'
      it_behaves_like 'SCIM API endpoints with scim_identities enabled'
    end
  end
end
