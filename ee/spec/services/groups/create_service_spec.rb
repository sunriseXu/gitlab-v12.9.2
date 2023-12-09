# frozen_string_literal: true

require 'spec_helper'

describe Groups::CreateService, '#execute' do
  let!(:user) { create :user }
  let!(:group_params) do
    {
      name: 'GitLab',
      path: 'group_path',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC
    }
  end

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { create_group(user, group_params) }
      let(:fail_condition!) do
        allow(Gitlab::VisibilityLevel).to receive(:allowed_for?).and_return(false)
      end
      let(:attributes) do
        {
           author_id: user.id,
           entity_id: @resource.id,
           entity_type: 'Group',
           details: {
             add: 'group',
             author_name: user.name,
             target_id: @resource.full_path,
             target_type: 'Group',
             target_details: @resource.full_path
           }
         }
      end
    end
  end

  context 'repository_size_limit assignment as Bytes' do
    let(:admin_user) { create(:user, admin: true) }

    context 'when param present' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'assign repository_size_limit as Bytes' do
        group = create_group(admin_user, group_params.merge(opts))

        expect(group.repository_size_limit).to eql(100 * 1024 * 1024)
      end
    end

    context 'when param not present' do
      let(:opts) { { repository_size_limit: '' } }

      it 'assign nil value' do
        group = create_group(admin_user, group_params.merge(opts))

        expect(group.repository_size_limit).to be_nil
      end
    end
  end

  context 'updating protected params' do
    let(:attrs) do
      group_params.merge(shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 100)
    end

    context 'as an admin' do
      let(:user) { create(:admin) }

      it 'updates the attributes' do
        group = create_group(user, attrs)

        expect(group.shared_runners_minutes_limit).to eq(1000)
        expect(group.extra_shared_runners_minutes_limit).to eq(100)
      end
    end

    context 'as a regular user' do
      it 'ignores the attributes' do
        group = create_group(user, attrs)

        expect(group.shared_runners_minutes_limit).to be_nil
        expect(group.extra_shared_runners_minutes_limit).to be_nil
      end
    end
  end

  def create_group(user, opts)
    described_class.new(user, opts).execute
  end
end
