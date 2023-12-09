# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Graphql::Loaders::BatchEpicIssuesLoader do
  describe '#find' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project1) { create(:project, :public, group: group) }
    let_it_be(:project2) { create(:project, :private, group: group) }
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: group) }
    let_it_be(:issue1) { create(:issue, project: project1) }
    let_it_be(:issue2) { create(:issue, project: project2) }
    let_it_be(:issue3) { create(:issue, project: project2) }
    let_it_be(:epic_issue1) { create(:epic_issue, epic: epic1, issue: issue1, relative_position: 1000) }
    let_it_be(:epic_issue2) { create(:epic_issue, epic: epic2, issue: issue2, relative_position: 99999) }
    let_it_be(:epic_issue3) { create(:epic_issue, epic: epic2, issue: issue3, relative_position: 1) }
    let(:filter) { proc {} }

    subject do
      [
        described_class.new(epic1.id, filter).find,
        described_class.new(epic2.id, filter).find
      ].map(&:sync)
    end

    it 'only queries once for epic issues' do
      # 6 queries are done: 2 queries in EachBatch and then getting issues
      # and getting projects, project_features and groups for these issues
      expect { subject }.not_to exceed_query_limit(6)
    end

    it 'returns all epic issues ordered by relative position' do
      expect(subject).to eq [[issue1], [issue3, issue2]]
    end

    it 'returns an instance of FilterableArray' do
      expect(subject.all?(Gitlab::Graphql::FilterableArray)).to be_truthy
    end

    it 'raises an error if too many issues are loaded' do
      stub_const('Gitlab::Graphql::Loaders::BatchEpicIssuesLoader::MAX_LOADED_ISSUES', 2)

      expect { subject }.to raise_error Gitlab::Graphql::Errors::ArgumentError, 'Too many epic issues requested.'
    end
  end
end
