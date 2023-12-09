# frozen_string_literal: true

require 'spec_helper'

describe API::LdapGroupLinks, api: true do
  include ApiHelpers

  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:admin) { create(:admin) }

  let!(:group_with_ldap_links) do
    group = create(:group)
    group.ldap_group_links.create cn: 'ldap-group1', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap1'
    group.ldap_group_links.create cn: 'ldap-group2', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap2'
    group.ldap_group_links.create filter: '(uid=mary)', group_access: Gitlab::Access::DEVELOPER, provider: 'ldap3'
    group
  end

  let(:group_with_no_ldap_links) { create(:group) }

  before do
    group_with_ldap_links.add_owner owner
    group_with_ldap_links.add_user user, Gitlab::Access::DEVELOPER
    group_with_no_ldap_links.add_owner owner
  end

  describe "GET /groups/:id/ldap_group_links" do
    context "when unauthenticated" do
      it "returns authentication error" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links")

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context "when a less priviledged user" do
      it "returns forbidden" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context "when owner of the group" do
      it "returns ldap group links" do
        get api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to(
          match([
            a_hash_including('cn' => 'ldap-group1', 'provider' => 'ldap1'),
            a_hash_including('cn' => 'ldap-group2', 'provider' => 'ldap2'),
            a_hash_including('cn' => nil, 'provider' => 'ldap3')
            ]))
      end

      it "returns error if no ldap group links found" do
        get api("/groups/#{group_with_no_ldap_links.id}/ldap_group_links", owner)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "POST /groups/:id/ldap_group_links" do
    context "when unauthenticated" do
      it "returns authentication error" do
        post api("/groups/#{group_with_ldap_links.id}/ldap_group_links")
        expect(response.status).to eq 401
      end
    end

    context "when a less priviledged user" do
      it "does not allow less priviledged user to add LDAP group link" do
        expect do
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", user),
          params: { cn: 'ldap-group4', group_access: GroupMember::GUEST, provider: 'ldap3' }
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response.status).to eq(403)
      end
    end

    context "when owner of the group" do
      it "returns ok and add ldap group link" do
        expect do
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
          params: { cn: 'ldap-group3', group_access: GroupMember::GUEST, provider: 'ldap3' }
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(1)

        expect(response.status).to eq(201)
        expect(json_response['cn']).to eq('ldap-group3')
        expect(json_response['group_access']).to eq(GroupMember::GUEST)
        expect(json_response['provider']).to eq('ldap3')
      end

      # TODO: Correct and activate this test once issue #329 is fixed
      xit "returns ok and add ldap group link even if no provider specified" do
        expect do
          post api("/groups/#{group_with_ldap_links.id}/ldap_group_links", owner),
          params: { cn: 'ldap-group3', group_access: GroupMember::GUEST }
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(1)

        expect(response.status).to eq(201)
        expect(json_response['cn']).to eq('ldap-group3')
        expect(json_response['group_access']).to eq(GroupMember::GUEST)
        expect(json_response['provider']).to eq('ldapmain')
      end

      it "returns error if LDAP group link already exists" do
        post api("//groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { provider: 'ldap1', cn: 'ldap-group1', group_access: GroupMember::GUEST }
        expect(response.status).to eq(409)
      end

      it "returns a 400 error when cn is not given" do
        post api("//groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { group_access: GroupMember::GUEST }
        expect(response.status).to eq(400)
      end

      it "returns a 400 error when group access is not given" do
        post api("//groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { cn: 'ldap-group3' }
        expect(response.status).to eq(400)
      end

      it "returns a 422 error when group access is not known" do
        post api("//groups/#{group_with_ldap_links.id}/ldap_group_links", owner), params: { cn: 'ldap-group3', group_access: 11, provider: 'ldap1' }

        expect(response.status).to eq(400)
        expect(json_response['error']).to eq('group_access does not have a valid value')
      end
    end
  end

  describe 'DELETE /groups/:id/ldap_group_links/:cn' do
    context "when unauthenticated" do
      it "returns authentication error" do
        delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1")
        expect(response.status).to eq 401
      end
    end

    context "when a less priviledged user" do
      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", user)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response.status).to eq(403)
      end
    end

    context "when owner of the group" do
      it "removes ldap group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1", owner)

          expect(response.status).to eq(204)
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(-1)
      end

      it "returns 404 if LDAP group cn not used for a LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap-group1356", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response.status).to eq(404)
      end
    end
  end

  describe 'DELETE /groups/:id/ldap_group_links/:provider/:cn' do
    context "when unauthenticated" do
      it "returns authentication error" do
        delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2")
        expect(response.status).to eq 401
      end
    end

    context "when a less priviledged user" do
      it "does not remove the LDAP group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2", user)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response.status).to eq(403)
      end
    end

    context "when owner of the group" do
      it "returns 404 if LDAP group cn not used for a LDAP group link for the specified provider" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap1/ldap-group2", owner)
        end.not_to change { group_with_ldap_links.ldap_group_links.count }

        expect(response.status).to eq(404)
      end

      it "removes ldap group link" do
        expect do
          delete api("/groups/#{group_with_ldap_links.id}/ldap_group_links/ldap2/ldap-group2", owner)

          expect(response.status).to eq(204)
        end.to change { group_with_ldap_links.ldap_group_links.count }.by(-1)
      end
    end
  end
end
