# frozen_string_literal: true

require 'spec_helper'

describe Snippet, :elastic do
  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it 'always returns global result for Elasticsearch indexing for #use_elasticsearch?' do
    snippet = create :snippet

    expect(snippet.use_elasticsearch?).to eq(true)

    stub_ee_application_setting(elasticsearch_indexing: false)

    expect(snippet.use_elasticsearch?).to eq(false)
  end

  context 'searching snippets by code' do
    let!(:author) { create(:user) }
    let!(:project) { create(:project) }

    let!(:public_snippet)   { create(:snippet, :public, content: 'password: XXX') }
    let!(:internal_snippet) { create(:snippet, :internal, content: 'password: XXX') }
    let!(:private_snippet)  { create(:snippet, :private, content: 'password: XXX', author: author) }

    let!(:project_public_snippet)   { create(:snippet, :public, project: project, content: 'password: 123') }
    let!(:project_internal_snippet) { create(:snippet, :internal, project: project, content: 'password: 456') }
    let!(:project_private_snippet)  { create(:snippet, :private, project: project, content: 'password: 789') }

    before do
      ensure_elasticsearch_index!
    end

    it 'returns only public snippets when user is blank', :sidekiq_might_not_need_inline do
      result = described_class.elastic_search_code('password', options: { current_user: nil })

      expect(result.total_count).to eq(1)
      expect(result.records).to match_array [public_snippet]
    end

    it 'returns only public and internal personal snippets for non-members', :sidekiq_might_not_need_inline do
      non_member = create(:user)

      result = described_class.elastic_search_code('password', options: { current_user: non_member })

      expect(result.total_count).to eq(2)
      expect(result.records).to match_array [public_snippet, internal_snippet]
    end

    it 'returns public, internal snippets, and project private snippets for project members', :sidekiq_might_not_need_inline do
      member = create(:user)
      project.add_developer(member)

      result = described_class.elastic_search_code('password', options: { current_user: member })

      expect(result.total_count).to eq(5)
      expect(result.records).to match_array [public_snippet, internal_snippet, project_public_snippet, project_internal_snippet, project_private_snippet]
    end

    it 'returns private snippets where the user is the author', :sidekiq_might_not_need_inline do
      result = described_class.elastic_search_code('password', options: { current_user: author })

      expect(result.total_count).to eq(3)
      expect(result.records).to match_array [public_snippet, internal_snippet, private_snippet]
    end

    it 'supports advanced search syntax', :sidekiq_might_not_need_inline do
      member = create(:user)
      project.add_reporter(member)

      result = described_class.elastic_search_code('password +(123 | 789)', options: { current_user: member })

      expect(result.total_count).to eq(2)
      expect(result.records).to match_array [project_public_snippet, project_private_snippet]
    end

    [:admin, :auditor].each do |user_type|
      it "returns all snippets for #{user_type}", :sidekiq_might_not_need_inline do
        superuser = create(user_type)

        result = described_class.elastic_search_code('password', options: { current_user: superuser })

        expect(result.total_count).to eq(6)
        expect(result.records).to match_array [public_snippet, internal_snippet, private_snippet, project_public_snippet, project_internal_snippet, project_private_snippet]
      end
    end

    describe 'when the user cannot read cross project' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
      end

      it 'returns public, internal snippets, but not project snippets', :sidekiq_might_not_need_inline do
        member = create(:user)
        project.add_developer(member)
        expect(Ability).to receive(:allowed?).with(member, :read_cross_project) { false }

        result = described_class.elastic_search_code('password', options: { current_user: member })

        expect(result.records).to match_array [public_snippet, internal_snippet]
      end
    end
  end

  it 'searches snippets by title and file_name' do
    user = create(:user)

    Sidekiq::Testing.inline! do
      create(:snippet, :public, title: 'home')
      create(:snippet, :private, title: 'home 1')
      create(:snippet, :public, file_name: 'index.php')
      create(:snippet)

      ensure_elasticsearch_index!
    end

    options = { current_user: user }

    expect(described_class.elastic_search('home', options: options).total_count).to eq(1)
    expect(described_class.elastic_search('index.php', options: options).total_count).to eq(1)
  end

  it 'returns json with all needed elements' do
    snippet = create(:project_snippet)

    expected_hash = snippet.attributes.extract!(
      'id',
      'title',
      'file_name',
      'content',
      'created_at',
      'description',
      'updated_at',
      'state',
      'project_id',
      'author_id',
      'visibility_level'
    ).merge({
      'type' => snippet.es_type
    })

    expect(snippet.__elasticsearch__.as_indexed_json).to eq(expected_hash)
  end

  it 'uses same index for Snippet subclasses' do
    Snippet.subclasses.each do |snippet_class|
      expect(snippet_class.index_name).to eq(Snippet.index_name)
      expect(snippet_class.document_type).to eq(Snippet.document_type)
      expect(snippet_class.__elasticsearch__.mappings.to_hash).to eq(Snippet.__elasticsearch__.mappings.to_hash)
    end
  end
end
