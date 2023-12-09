# frozen_string_literal: true

require 'spec_helper'

describe SamlProvider do
  let(:group) { create(:group) }

  subject(:saml_provider) { create(:saml_provider, group: group) }

  before do
    stub_licensed_features(group_saml: true)
  end

  describe "Associations" do
    it { is_expected.to belong_to :group }
    it { is_expected.to have_many :identities }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:sso_url) }
    it { is_expected.to validate_presence_of(:certificate_fingerprint) }

    it 'expects sso_url to be an https URL' do
      expect(subject).to allow_value('https://example.com').for(:sso_url)
      expect(subject).not_to allow_value('http://example.com').for(:sso_url)
    end

    it 'prevents homoglyph phishing attacks by only allowing ascii URLs' do
      expect(subject).to allow_value('https://gitlab.com/adfs/ls').for(:sso_url)
      expect(subject).not_to allow_value('https://𝕘itⅼaƄ.ᴄοｍ/adfs/ls').for(:sso_url)
    end

    it 'allows unicode domain names when encoded as ascii punycode' do
      expect(subject).to allow_value('https://xn--gitl-ocb944a.xn--m-rmb025q/adfs/ls').for(:sso_url)
    end

    it 'expects certificate_fingerprint to be in an accepted format' do
      expect(subject).to allow_value('000030EDC285E01D6B5EA33010A79ADD142F5004').for(:certificate_fingerprint)
      expect(subject).to allow_value('00:00:30:ED:C2:85:E0:1D:6B:5E:A3:30:10:A7:9A:DD:14:2F:50:04').for(:certificate_fingerprint)
      expect(subject).to allow_value('00-00-30-ED-C2-85-E0-1D-6B-5E-A3-30-10-A7-9A-DD-14-2F-50-04').for(:certificate_fingerprint)
      expect(subject).to allow_value('00 00 30 ED C2 85 E0 1D 6B 5E A3 30 10 A7 9A DD 14 2F 50 04').for(:certificate_fingerprint)
      sha512 = 'a12bc3d4567ef89ba97f4d1904815d56a497ffc2fe9d5b0f13439a5da73f4f1afde03b1c1b213128e173da24e75cadf224286696f5171540eedf59b684a5f8dd'
      expect(subject).to allow_value(sha512).for(:certificate_fingerprint)

      too_short = '00:00:30'
      invalid_characters = '00@0030EDC285E01D6B5EA33010A79ADD142F5004'
      expect(subject).not_to allow_value(too_short).for(:certificate_fingerprint)
      expect(subject).not_to allow_value(invalid_characters).for(:certificate_fingerprint)
    end

    it 'strips left-to-right marks from certificate_fingerprint' do
      expect(subject).to allow_value("\u200E00 00 30 ED C2 85 E0 1D 6B 5E A3 30 10 A7 9A DD 14 2F 50 04‎").for(:certificate_fingerprint)
    end

    it 'requires group to be top-level' do
      group = create(:group)
      nested_group = create(:group, :nested)

      expect(subject).to allow_value(group).for(:group)
      expect(subject).not_to allow_value(nested_group).for(:group)
    end
  end

  describe 'Default values' do
    it 'defaults enabled to true' do
      expect(subject).to be_enabled
    end
  end

  describe '#settings' do
    let(:group) { create(:group, path: 'foo-group') }
    let(:settings) { subject.settings }

    before do
      stub_default_url_options(protocol: "https")
    end

    it 'generates callback URL' do
      expect(settings[:assertion_consumer_service_url]).to eq "https://localhost/groups/foo-group/-/saml/callback"
    end

    it 'generates issuer from group' do
      expect(settings[:issuer]).to eq "https://localhost/groups/foo-group"
    end

    it 'includes NameID format' do
      expect(settings[:name_identifier_format]).to start_with 'urn:oasis:names:tc:'
    end

    it 'includes fingerprint' do
      expect(settings[:idp_cert_fingerprint]).to eq saml_provider.certificate_fingerprint
    end

    it 'includes SSO URL' do
      expect(settings[:idp_sso_target_url]).to eq saml_provider.sso_url
    end
  end

  describe '#enforced_sso?' do
    context 'when provider is enabled' do
      before do
        subject.enabled = true
      end

      it 'matches attribute' do
        subject.enforced_sso = true
        expect(subject).to be_enforced_sso
        subject.enforced_sso = false
        expect(subject).not_to be_enforced_sso
      end

      context 'and feature flag is disabled' do
        before do
          stub_feature_flags(enforced_sso: false)
        end

        it 'is false' do
          subject.enforced_sso = true

          expect(subject).not_to be_enforced_sso
        end
      end

      it 'does not enforce SSO when the feature is unavailable' do
        stub_licensed_features(group_saml: false)
        subject.enforced_sso = true

        expect(subject).not_to be_enforced_sso
      end
    end

    context 'when provider is disabled' do
      before do
        subject.enabled = false
      end

      it 'ignores attribute value' do
        subject.enforced_sso = true
        expect(subject).not_to be_enforced_sso
        subject.enforced_sso = false
        expect(subject).not_to be_enforced_sso
      end
    end
  end

  describe '#enforced_group_managed_accounts?' do
    before do
      stub_feature_flags(group_managed_accounts: true)
    end

    context 'when enforced_sso is enabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = true
      end

      it 'matches attribute' do
        subject.enforced_group_managed_accounts = true
        expect(subject).to be_enforced_group_managed_accounts
        subject.enforced_group_managed_accounts = false
        expect(subject).not_to be_enforced_group_managed_accounts
      end

      context 'and feature flag is disabled' do
        before do
          stub_feature_flags(group_managed_accounts: false)
        end

        it 'is false' do
          subject.enforced_group_managed_accounts = true

          expect(subject).not_to be_enforced_group_managed_accounts
        end
      end
    end

    context 'when enforced_sso is disabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = false
      end

      it 'ignores attribute value' do
        subject.enforced_group_managed_accounts = true
        expect(subject).not_to be_enforced_group_managed_accounts
        subject.enforced_group_managed_accounts = false
        expect(subject).not_to be_enforced_group_managed_accounts
      end
    end
  end

  describe '#prohibited_outer_forks?' do
    context 'without enforced GMA' do
      it 'is false when prohibited_outer_forks flag value is true' do
        subject.prohibited_outer_forks = true

        expect(subject.prohibited_outer_forks?).to be_falsey
      end

      it 'is false when prohibited_outer_forks flag value is false' do
        subject.prohibited_outer_forks = false

        expect(subject.prohibited_outer_forks?).to be_falsey
      end
    end

    context 'when enforced GMA is enabled' do
      before do
        subject.enabled = true
        subject.enforced_sso = true
        subject.enforced_group_managed_accounts = true
      end

      it 'is true when prohibited_outer_forks flag value is true' do
        subject.prohibited_outer_forks = true

        expect(subject.prohibited_outer_forks?).to be_truthy
      end

      it 'is false when prohibited_outer_forks flag value is false' do
        subject.prohibited_outer_forks = false

        expect(subject.prohibited_outer_forks?).to be_falsey
      end
    end
  end
end
