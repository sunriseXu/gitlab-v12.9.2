# frozen_string_literal: true

require 'spec_helper'

describe 'Login' do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  it 'creates a security event for an invalid password login' do
    user = create(:user, password: 'not-the-default')

    expect { gitlab_sign_in(user) }
      .to change { SecurityEvent.where(entity_id: -1).count }.from(0).to(1)
  end

  it 'creates a security event for an invalid OAuth login' do
    stub_omniauth_saml_config(
      enabled: true,
      auto_link_saml_user: false,
      allow_single_sign_on: ['saml'],
      providers: [mock_saml_config]
    )

    user = create(:omniauth_user, :two_factor, extern_uid: 'my-uid', provider: 'saml')

    expect { gitlab_sign_in_via('saml', user, 'wrong-uid') }
      .to change { SecurityEvent.where(entity_id: -1).count }.from(0).to(1)
  end

  describe 'smartcard authentication' do
    before do
      allow(Gitlab.config.smartcard).to receive(:enabled).and_return(true)
    end

    subject { visit new_user_session_path }

    context 'when smartcard is enabled' do
      context 'with smartcard_auth feature flag off' do
        before do
          stub_licensed_features(smartcard_auth: false)
        end

        it 'correctly renders tabs and panes' do
          subject

          ensure_tab_pane_correctness(false)
        end

        it 'does not show smartcard login form' do
          subject

          expect(page).not_to have_selector('.nav-tabs a[href="#smartcard"]')
        end
      end

      context 'with smartcard_auth feature flag on' do
        before do
          stub_licensed_features(smartcard_auth: true)
        end

        it 'correctly renders tabs and panes' do
          subject

          expect(page.all('.nav-tabs a[data-toggle="tab"]').length).to be(3)

          ensure_one_active_tab
          ensure_one_active_pane
        end

        it 'shows smartcard login form' do
          subject

          expect(page).to have_selector('.nav-tabs a[href="#smartcard"]')
        end
      end
    end
  end

  describe 'smartcard authentication against LDAP server' do
    let(:ldap_server_config) do
      {
        'provider_name' => 'ldapmain',
        'attributes' => {},
        'encryption' => 'plain',
        'smartcard_auth' => smartcard_auth_status,
        'uid' => 'uid',
        'base' => 'dc=example,dc=com'
      }
    end

    subject { visit new_user_session_path }

    before do
      stub_licensed_features(smartcard_auth: true)
      stub_ldap_setting(enabled: true)
      allow(Gitlab.config.smartcard).to receive(:enabled).and_return(true)
      allow(::Gitlab::Auth::Ldap::Config).to receive_messages(enabled: true, servers: [ldap_server_config])
      allow_any_instance_of(ActionDispatch::Routing::RoutesProxy)
        .to receive(:user_ldapmain_omniauth_callback_path)
              .and_return('/users/auth/ldapmain/callback')
    end

    context 'when smartcard auth is optional' do
      let(:smartcard_auth_status) { 'optional' }

      it 'correctly renders tabs and panes' do
        subject

        ensure_one_active_tab
        ensure_one_active_pane
      end

      it 'shows LDAP login form' do
        subject

        expect(page).to have_selector('#ldapmain.tab-pane form#new_ldap_user')
      end

      it 'shows LDAP smartcard login form' do
        subject

        expect(page).to have_selector('#ldapmain_smartcard input[value="Sign in with smart card"]')
      end
    end

    context 'when smartcard auth is required' do
      let(:smartcard_auth_status) { 'required' }

      it 'correctly renders tabs and panes' do
        subject

        ensure_one_active_tab
        ensure_one_active_pane
      end

      it 'does not show LDAP login form' do
        subject

        expect(page).not_to have_selector('#ldapmain.tab-pane form#new_ldap_user')
      end

      it 'shows LDAP smartcard login form' do
        subject

        expect(page).to have_selector('#ldapmain_smartcard input[value="Sign in with smart card"]')
      end
    end
  end

  describe 'via Group SAML' do
    let(:saml_provider) { create(:saml_provider) }
    let(:group) { saml_provider.group }
    let(:identity) { create(:group_saml_identity, user: user, saml_provider: saml_provider) }

    before do
      stub_licensed_features(group_saml: true)
    end

    around(:all) do |example|
      with_omniauth_full_host { example.run }
    end

    context 'with U2F two factor', :js do
      let(:user) { create(:user, :two_factor_via_u2f) }

      before do
        mock_group_saml(uid: identity.extern_uid)
      end

      it 'shows U2F prompt after SAML' do
        visit sso_group_saml_providers_path(group, token: group.saml_discovery_token)

        click_link 'Sign in with Single Sign-On'

        expect(page).to have_content('Trying to communicate with your device')
        expect(page).to have_link('Sign in via 2FA code')

        fake_successful_u2f_authentication

        expect(current_path).to eq root_path
      end
    end
  end
end
