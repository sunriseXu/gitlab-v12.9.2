# frozen_string_literal: true

require 'spec_helper'

describe ::EE::Gitlab::Scim::ProvisioningService do
  describe '#execute' do
    let(:group) { create(:group) }
    let(:service) { described_class.new(group, service_params) }

    before do
      stub_licensed_features(group_saml: true)
    end

    shared_examples 'scim provisioning' do
      context 'valid params' do
        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: 'test_uid',
            username: 'username'
          }
        end

        def user
          User.find_by(email: service_params[:email])
        end

        it 'succeeds' do
          expect(service.execute.status).to eq(:success)
        end

        it 'creates the user' do
          expect { service.execute }.to change { User.count }.by(1)
        end

        it 'creates the group member' do
          expect { service.execute }.to change { GroupMember.count }.by(1)
        end

        it 'creates the correct user attributes' do
          service.execute

          expect(user).to be_a(User)
        end

        it 'creates the member with guest access level' do
          service.execute

          access_level = group.group_member(user).access_level

          expect(access_level).to eq(Gitlab::Access::GUEST)
        end

        it 'user record requires confirmation' do
          service.execute

          expect(user).to be_present
          expect(user).not_to be_confirmed
        end

        context 'when the current minimum password length is different from the default minimum password length' do
          before do
            stub_application_setting minimum_password_length: 21
          end

          it 'creates the user' do
            expect { service.execute }.to change { User.count }.by(1)
          end
        end

        context 'existing user' do
          before do
            create(:user, email: 'work@example.com')
          end

          it 'does not create a new user' do
            expect { service.execute }.not_to change { User.count }
          end

          it 'fails with conflict' do
            expect(service.execute.status).to eq(:conflict)
          end
        end
      end

      context 'invalid params' do
        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: 'test_uid'
          }
        end

        it 'fails with error' do
          expect(service.execute.status).to eq(:error)
        end
      end
    end

    context 'when scim_identities is disabled' do
      before do
        stub_feature_flags(scim_identities: false)
        create(:saml_provider, group: group)
      end

      let_it_be(:service_params) do
        {
          email: 'work@example.com',
          name: 'Test Name',
          extern_uid: 'test_uid',
          username: 'username'
        }
      end

      it_behaves_like 'scim provisioning'

      it 'creates the identity' do
        expect { service.execute }.to change { Identity.count }.by(1)
        expect { service.execute }.not_to change { ScimIdentity.count }
      end
    end

    context 'when scim_identities is enabled' do
      before do
        stub_feature_flags(scim_identities: true)
      end

      let_it_be(:service_params) do
        {
          email: 'work@example.com',
          name: 'Test Name',
          extern_uid: 'test_uid',
          username: 'username'
        }
      end

      it_behaves_like 'scim provisioning'

      it 'creates the scim identity' do
        expect { service.execute }.to change { ScimIdentity.count }.by(1)
        expect { service.execute }.not_to change { Identity.count }
      end
    end
  end
end
