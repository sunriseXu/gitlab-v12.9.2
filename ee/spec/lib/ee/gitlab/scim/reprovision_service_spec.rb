# frozen_string_literal: true

require 'spec_helper'

describe ::EE::Gitlab::Scim::ReprovisionService do
  describe '#execute' do
    let_it_be(:identity) { create(:scim_identity, active: false) }
    let_it_be(:group) { identity.group }
    let_it_be(:user) { identity.user }

    let(:service) { described_class.new(identity) }

    it 'activates scim identity' do
      service.execute

      expect(identity.active).to be true
    end

    it 'creates the member' do
      service.execute

      expect(group.members.pluck(:user_id)).to include(user.id)
    end

    it 'creates the member with guest access level' do
      service.execute

      access_level = group.group_member(user).access_level

      expect(access_level).to eq(Gitlab::Access::GUEST)
    end

    it 'does not change group membership when the user is already a member' do
      create(:group_member, group: group, user: user)

      expect { service.execute }.not_to change { group.members.count }
    end
  end
end
