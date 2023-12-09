# frozen_string_literal: true

require 'spec_helper'

describe EE::GitlabRoutingHelper do
  include ProjectsHelper
  include ApplicationSettingsHelper

  let_it_be(:primary, reload: true) { create(:geo_node, :primary, url: 'http://localhost:123/relative', clone_url_prefix: 'git@localhost:') }
  let_it_be(:group, reload: true) { create(:group, path: 'foo') }
  let_it_be(:project, reload: true) { create(:project, namespace: group, path: 'bar') }

  describe '#geo_primary_web_url' do
    before do
      allow(helper).to receive(:default_clone_protocol).and_return('http')
    end

    it 'generates a path to the project' do
      result = helper.geo_primary_web_url(project)

      expect(result).to eq('http://localhost:123/relative/foo/bar')
    end

    it 'generates a path to the wiki' do
      result = helper.geo_primary_web_url(project.wiki)

      expect(result).to eq('http://localhost:123/relative/foo/bar.wiki')
    end
  end

  describe '#geo_primary_default_url_to_repo' do
    subject { helper.geo_primary_default_url_to_repo(repo) }

    context 'HTTP' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('http')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq('http://localhost:123/relative/foo/bar.git') }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq('http://localhost:123/relative/foo/bar.wiki.git') }
      end
    end

    context 'HTTPS' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('https')
        primary.update!(url: 'https://localhost:123/relative')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq('https://localhost:123/relative/foo/bar.git') }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq('https://localhost:123/relative/foo/bar.wiki.git') }
      end
    end

    context 'SSH' do
      before do
        allow(helper).to receive(:default_clone_protocol).and_return('ssh')
      end

      context 'project' do
        let(:repo) { project }

        it { is_expected.to eq('git@localhost:foo/bar.git') }
      end

      context 'wiki' do
        let(:repo) { project.wiki }

        it { is_expected.to eq('git@localhost:foo/bar.wiki.git') }
      end
    end
  end

  describe '#user_group_saml_omniauth_metadata_path' do
    subject do
      helper.user_group_saml_omniauth_metadata_path(group)
    end

    before do
      group.update!(saml_discovery_token: 'sometoken')
    end

    it 'uses metadata path' do
      expect(subject).to start_with('/users/auth/group_saml/metadata')
    end

    it 'appends group path and token' do
      expect(subject).to end_with('?group_path=foo&token=sometoken')
    end
  end

  describe '#user_group_saml_omniauth_metadata_url' do
    subject do
      helper.user_group_saml_omniauth_metadata_url(group)
    end

    it 'creates full metadata URL' do
      expect(subject).to start_with 'http://localhost/users/auth/group_saml/metadata?group_path=foo&token='
    end
  end
end
