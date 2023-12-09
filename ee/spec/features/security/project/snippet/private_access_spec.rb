# frozen_string_literal: true

require 'spec_helper'

describe "Private Project Snippets Access" do
  include AccessMatchers

  let(:project) { create(:project, :private) }

  let(:private_snippet) { create(:project_snippet, :private, project: project, author: project.owner) }

  describe "GET /:project_path/snippets" do
    subject { project_snippets_path(project) }

    it { is_expected.to be_allowed_for(:auditor) }
  end

  describe "GET /:project_path/snippets/new" do
    subject { new_project_snippet_path(project) }

    it { is_expected.to be_denied_for(:auditor) }
  end

  describe "GET /:project_path/snippets/:id for a private snippet" do
    subject { project_snippet_path(project, private_snippet) }

    it { is_expected.to be_allowed_for(:auditor) }
  end

  describe "GET /:project_path/snippets/:id/raw for a private snippet" do
    subject { raw_project_snippet_path(project, private_snippet) }

    it { is_expected.to be_allowed_for(:auditor) }
  end
end
