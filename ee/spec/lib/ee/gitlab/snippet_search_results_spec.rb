# frozen_string_literal: true
require 'spec_helper'

describe Gitlab::SnippetSearchResults do
  let!(:snippet) { create(:snippet, content: 'foo', file_name: 'foo') }
  let(:user) { snippet.author }
  let(:com_value) { true }
  let(:flag_enabled) { true }

  subject { described_class.new(user, 'foo').objects('snippet_titles') }

  before do
    allow(Gitlab).to receive(:com?).and_return(com_value)
    stub_feature_flags(restricted_snippet_scope_search: flag_enabled)
  end

  context 'when all requirements are met' do
    it 'calls the finder with the restrictive scope' do
      expect(SnippetsFinder).to receive(:new).with(user, authorized_and_user_personal: true).and_call_original

      subject
    end
  end

  context 'when not in Gitlab.com' do
    let(:com_value) { false }

    it 'calls the finder with the restrictive scope' do
      expect(SnippetsFinder).to receive(:new).with(user, {}).and_call_original

      subject
    end
  end

  context 'when flag restricted_snippet_scope_search is not enabled' do
    let(:flag_enabled) { false }

    it 'calls the finder with the restrictive scope' do
      expect(SnippetsFinder).to receive(:new).with(user, {}).and_call_original

      subject
    end
  end
end
