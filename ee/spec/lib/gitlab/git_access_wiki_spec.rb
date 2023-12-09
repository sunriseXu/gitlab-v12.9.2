# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::GitAccessWiki do
  let(:user) { create(:user) }
  let(:project) { create(:project, :wiki_repo) }
  let(:changes) { ['6f6d7e7ed 570e7b2ab refs/heads/master'] }
  let(:authentication_abilities) { %i[read_project download_code push_code] }
  let(:redirected_path) { nil }

  let(:access) { described_class.new(user, project, 'web', authentication_abilities: authentication_abilities, redirected_path: redirected_path) }

  context "when in a read-only GitLab instance" do
    subject { access.check('git-receive-pack', changes) }

    before do
      create(:protected_branch, name: 'feature', project: project)
      allow(Gitlab::Database).to receive(:read_only?) { true }
    end

    let(:primary_repo_url) { geo_primary_http_url_to_repo(project.wiki) }
    let(:primary_repo_ssh_url) { geo_primary_ssh_url_to_repo(project.wiki) }

    it_behaves_like 'a read-only GitLab instance'
  end

  context 'when wiki is disabled' do
    let(:user) { :geo }
    let(:project) { create(:project, :private, :wiki_repo, wiki_access_level: ProjectFeature::DISABLED) }
    let(:authentication_abilities) { [:download_code] }

    subject { access.check('git-upload-pack', changes) }

    it 'allows code download for geo' do
      expect(subject).to be_truthy
    end
  end

  private

  def push_changes(changes = Gitlab::GitAccess::ANY)
    access.check('git-receive-pack', changes)
  end

  # It is needed by the shared examples
  def raise_forbidden(message)
    raise_error(Gitlab::GitAccess::ForbiddenError, message)
  end
end
