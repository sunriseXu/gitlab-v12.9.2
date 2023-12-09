# frozen_string_literal: true

require 'spec_helper'

describe ScimFinder do
  let(:group) { create(:group) }
  let(:unused_params) { double }

  subject(:finder) { described_class.new(group) }

  describe '#search' do
    context 'without a SAML provider' do
      it 'returns an empty identity relation when scim_identities is disabled' do
        stub_feature_flags(scim_identities: false)

        expect(finder.search(unused_params)).to eq Identity.none
      end

      it 'returns an empty scim identity relation when scim_identities is enabled' do
        stub_feature_flags(scim_identities: true)

        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end

    context 'SCIM/SAML is not enabled' do
      before do
        create(:saml_provider, group: group, enabled: false)
      end

      it 'returns an empty identity relation when scim_identities is disabled' do
        stub_feature_flags(scim_identities: false)

        expect(finder.search(unused_params)).to eq Identity.none
      end

      it 'returns an empty scim identity relation when scim_identities is enabled' do
        stub_feature_flags(scim_identities: true)

        expect(finder.search(unused_params)).to eq ScimIdentity.none
      end
    end

    context 'with SCIM enabled' do
      let!(:saml_provider) { create(:saml_provider, group: group) }

      context 'with an eq filter' do
        shared_examples 'valid lookups' do
          it 'allows identity lookup by id/externalId' do
            expect(finder.search(filter: "id eq #{id.extern_uid}")).to be_a ActiveRecord::Relation
            expect(finder.search(filter: "id eq #{id.extern_uid}").first).to eq id
            expect(finder.search(filter: "externalId eq #{id.extern_uid}").first).to eq id
          end

          it 'allows lookup by userName' do
            expect(finder.search(filter: "userName eq \"#{id.user.username}\"").first).to eq id
          end

          it 'allows lookup by userName when userName is an email address' do
            expect(finder.search(filter: "userName eq #{id.user.email}").first).to eq id
          end
        end

        context 'when scim_identities is disabled' do
          before do
            stub_feature_flags(scim_identities: false)
          end
          let(:id) { create(:group_saml_identity, saml_provider: saml_provider) }

          it_behaves_like 'valid lookups'
        end

        context 'when scim_identities is enabled' do
          before do
            stub_feature_flags(scim_identities: true)
          end
          let(:id) { create(:scim_identity, group: group) }

          it_behaves_like 'valid lookups'
        end
      end

      context 'with no filter' do
        it 'returns all related identities when scim_identities is disabled' do
          stub_feature_flags(scim_identities: false)
          create_list(:group_saml_identity, 2, saml_provider: saml_provider)

          expect(finder.search({}).count).to eq 2
        end

        it 'returns all related identities when scim_identities is enabled' do
          stub_feature_flags(scim_identities: true)
          create_list(:scim_identity, 4, group: group)

          expect(finder.search({}).count).to eq 4
        end
      end

      it 'raises an error if the filter is unsupported' do
        expect { finder.search(filter: 'id ne 1').count }.to raise_error(ScimFinder::UnsupportedFilter)
      end

      it 'raises an error if the attribute path is unsupported' do
        expect { finder.search(filter: 'displayName eq "name"').count }.to raise_error(ScimFinder::UnsupportedFilter)
      end
    end
  end
end
