# frozen_string_literal: true

require 'spec_helper'

describe Epic do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let(:project) { create(:project, group: group) }

  describe 'associations' do
    subject { build(:epic) }

    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to belong_to(:assignee).class_name('User') }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:parent) }
    it { is_expected.to have_many(:epic_issues) }
    it { is_expected.to have_many(:children) }
    it { is_expected.to have_many(:user_mentions).class_name("EpicUserMention") }
  end

  describe 'validations' do
    subject { build(:epic) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_presence_of(:title) }

    it 'is valid with a valid parent' do
      epic = build(:epic, group: group, parent: create(:epic, group: group))

      expect(epic).to be_valid
    end

    it 'is not valid with invalid parent' do
      epic = build(:epic, group: group, parent: create(:epic))

      expect(epic).not_to be_valid
    end
  end

  describe 'modules' do
    subject { described_class }

    it_behaves_like 'AtomicInternalId' do
      let(:internal_id_attribute) { :iid }
      let(:instance) { build(:epic) }
      let(:scope) { :group }
      let(:scope_attrs) { { namespace: instance.group } }
      let(:usage) { :epics }
    end
  end

  describe 'ordering' do
    let!(:epic1) { create(:epic, start_date: 7.days.ago, end_date: 3.days.ago, updated_at: 3.days.ago, created_at: 7.days.ago, relative_position: 3) }
    let!(:epic2) { create(:epic, start_date: 3.days.ago, updated_at: 10.days.ago, created_at: 12.days.ago, relative_position: 1) }
    let!(:epic3) { create(:epic, end_date: 5.days.ago, updated_at: 5.days.ago, created_at: 6.days.ago, relative_position: 2) }
    let!(:epic4) { create(:epic, relative_position: 4) }

    def epics(order_by)
      described_class.order_by(order_by)
    end

    it 'orders by start_or_end_date' do
      expect(epics(:start_or_end_date)).to eq([epic4, epic1, epic3, epic2])
    end

    it 'orders by start_date ASC' do
      expect(epics(:start_date_asc)).to eq([epic1, epic2, epic4, epic3])
    end

    it 'orders by start_date DESC' do
      expect(epics(:start_date_desc)).to eq([epic2, epic1, epic4, epic3])
    end

    it 'orders by end_date ASC' do
      expect(epics(:end_date_asc)).to eq([epic3, epic1, epic4, epic2])
    end

    it 'orders by end_date DESC' do
      expect(epics(:end_date_desc)).to eq([epic1, epic3, epic4, epic2])
    end

    it 'orders by updated_at ASC' do
      expect(epics(:updated_asc)).to eq([epic2, epic3, epic1, epic4])
    end

    it 'orders by updated_at DESC' do
      expect(epics(:updated_desc)).to eq([epic4, epic1, epic3, epic2])
    end

    it 'orders by created_at ASC' do
      expect(epics(:created_asc)).to eq([epic2, epic1, epic3, epic4])
    end

    it 'orders by created_at DESC' do
      expect(epics(:created_desc)).to eq([epic4, epic3, epic1, epic2])
    end

    it 'orders by relative_position ASC' do
      expect(epics(:relative_position)).to eq([epic2, epic3, epic1, epic4])
    end
  end

  describe '#valid_parent?' do
    context 'basic checks' do
      let(:epic) { build(:epic, group: group) }

      it 'returns true without parent' do
        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns true with a valid parent' do
        epic.parent = create(:epic, group: group)

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false with a parent from different group' do
        epic.parent = create(:epic)

        expect(epic.valid_parent?).to be_falsey
      end

      it 'returns false when level is too deep' do
        epic1 = create(:epic, group: group)
        epic2 = create(:epic, group: group, parent: epic1)
        epic3 = create(:epic, group: group, parent: epic2)
        epic4 = create(:epic, group: group, parent: epic3)
        epic5 = create(:epic, group: group, parent: epic4)
        epic.parent = epic5

        expect(epic.valid_parent?).to be_falsey
      end
    end

    context 'when adding an Epic that has existing children' do
      let(:parent_epic) { create(:epic, group: group) }
      let(:epic) { build(:epic, group: group) }
      let(:child_epic1) { create(:epic, group: group, parent: epic)}

      it 'returns true when total depth after adding will not exceed limit' do
        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false when total depth after adding would exceed limit' do
        child_epic2 = create(:epic, group: group, parent: child_epic1)
        child_epic3 = create(:epic, group: group, parent: child_epic2)
        create(:epic, group: group, parent: child_epic3)

        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_falsey
      end
    end

    context 'when parent has ancestors and epic has children' do
      let(:root_epic) { create(:epic, group: group) }
      let(:parent_epic) { create(:epic, group: group, parent: root_epic) }
      let(:epic) { build(:epic, group: group) }
      let(:child_epic1) { create(:epic, group: group, parent: epic)}

      it 'returns true when total depth after adding will not exceed limit' do
        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false when total depth after adding would exceed limit' do
        root_epic.update(parent: create(:epic, group: group))
        create(:epic, group: group, parent: child_epic1)

        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_falsey
      end
    end

    context 'when hierarchy is cyclic' do
      let(:epic) { create(:epic, group: group) }

      it 'returns false when parent is same as the epic' do
        epic.parent = epic

        expect(epic.valid_parent?).to be_falsey
      end

      it 'returns false when child epic is parent of the given parent' do
        epic1 = create(:epic, group: group, parent: epic)
        epic.parent = epic1

        expect(epic.valid_parent?).to be_falsey
      end

      it 'returns false when child epic is an ancestor of the given parent' do
        epic1 = create(:epic, group: group, parent: epic)
        epic2 = create(:epic, group: group, parent: epic1)
        epic.parent = epic2

        expect(epic.valid_parent?).to be_falsey
      end
    end
  end

  context 'hierarchy' do
    let(:epic1) { create(:epic, group: group) }
    let(:epic2) { create(:epic, group: group, parent: epic1) }
    let(:epic3) { create(:epic, group: group, parent: epic2) }

    describe '#ancestors' do
      it 'returns all ancestors for an epic' do
        expect(epic3.ancestors).to eq [epic2, epic1]
      end

      it 'returns an empty array if an epic does not have any parent' do
        expect(epic1.ancestors).to be_empty
      end
    end

    describe '#descendants' do
      it 'returns all descendants for an epic' do
        expect(epic1.descendants).to match_array([epic2, epic3])
      end

      it 'returns an empty array if an epic does not have any descendants' do
        expect(epic3.descendants).to be_empty
      end
    end
  end

  describe '#upcoming?' do
    it 'returns true when start_date is in the future' do
      epic = build(:epic, start_date: 1.month.from_now)

      expect(epic.upcoming?).to be_truthy
    end

    it 'returns false when start_date is in the past' do
      epic = build(:epic, start_date: Date.today.prev_year)

      expect(epic.upcoming?).to be_falsey
    end
  end

  describe '#expired?' do
    it 'returns true when due_date is in the past' do
      epic = build(:epic, end_date: Date.today.prev_year)

      expect(epic.expired?).to be_truthy
    end

    it 'returns false when due_date is in the future' do
      epic = build(:epic, end_date: Date.today.next_year)

      expect(epic.expired?).to be_falsey
    end
  end

  describe '#elapsed_days' do
    it 'returns 0 if there is no start_date' do
      epic = build(:epic)

      expect(epic.elapsed_days).to eq(0)
    end

    it 'returns elapsed_days when start_date is present' do
      epic = build(:epic, start_date: 7.days.ago)

      expect(epic.elapsed_days).to eq(7)
    end
  end

  describe '#start_date' do
    let(:date) { Date.new(2000, 1, 1) }

    context 'is set' do
      subject { build(:epic, :use_fixed_dates, start_date: date) }

      it 'returns as is' do
        expect(subject.start_date).to eq(date)
      end
    end
  end

  it_behaves_like 'within_timeframe scope' do
    let_it_be(:now) { Time.now }
    let_it_be(:group) { create(:group) }
    let_it_be(:resource_1) { create(:epic, group: group, start_date: now - 1.day, end_date: now + 1.day) }
    let_it_be(:resource_2) { create(:epic, group: group, start_date: now + 2.days, end_date: now + 3.days) }
    let_it_be(:resource_3) { create(:epic, group: group, end_date: now) }
    let_it_be(:resource_4) { create(:epic, group: group, start_date: now) }
  end

  describe '#start_date_from_milestones' do
    context 'fixed date' do
      it 'returns start date from start date sourcing milestone' do
        subject = create(:epic, :use_fixed_dates)
        milestone = create(:milestone, :with_dates)
        subject.start_date_sourcing_milestone = milestone

        expect(subject.start_date_from_milestones).to eq(milestone.start_date)
      end
    end

    context 'milestone date' do
      it 'returns start_date' do
        subject = create(:epic, start_date: Date.new(2017, 3, 4))

        expect(subject.start_date_from_milestones).to eq(subject.start_date)
      end
    end
  end

  describe '#due_date_from_milestones' do
    context 'fixed date' do
      it 'returns due date from due date sourcing milestone' do
        subject = create(:epic, :use_fixed_dates)
        milestone = create(:milestone, :with_dates)
        subject.due_date_sourcing_milestone = milestone

        expect(subject.due_date_from_milestones).to eq(milestone.due_date)
      end
    end

    context 'milestone date' do
      it 'returns due_date' do
        subject = create(:epic, due_date: Date.new(2017, 3, 4))

        expect(subject.due_date_from_milestones).to eq(subject.due_date)
      end
    end
  end

  describe '.deepest_relationship_level' do
    context 'when there are no epics' do
      it 'returns nil' do
        expect(described_class.deepest_relationship_level).to be_nil
      end
    end

    it 'returns the deepest relationship level between epics' do
      group_1 = create(:group)
      group_2 = create(:group)

      # No relationship
      create(:epic, group: group_1)

      # Two levels relationship
      group_1_epic_1 = create(:epic, group: group_1)
      create(:epic, group: group_1, parent: group_1_epic_1)

      # Three levels relationship
      group_2_epic_1 = create(:epic, group: group_2)
      group_2_epic_2 = create(:epic, group: group_2, parent: group_2_epic_1)
      create(:epic, group: group_2, parent: group_2_epic_2)

      expect(described_class.deepest_relationship_level).to eq(3)
    end
  end

  describe '#issues_readable_by' do
    let(:group) { create(:group, :private) }
    let(:project) { create(:project, group: group) }
    let(:project2) { create(:project, group: group) }

    let!(:epic) { create(:epic, group: group) }
    let!(:issue) { create(:issue, project: project)}
    let!(:lone_issue) { create(:issue, project: project)}
    let!(:other_issue) { create(:issue, project: project2)}
    let!(:epic_issues) do
      [
        create(:epic_issue, epic: epic, issue: issue),
        create(:epic_issue, epic: epic, issue: other_issue)
      ]
    end

    let(:result) { epic.issues_readable_by(user) }

    it 'returns all issues if a user has access to them' do
      group.add_developer(user)

      expect(result.count).to eq(2)
      expect(result.map(&:id)).to match_array([issue.id, other_issue.id])
      expect(result.map(&:epic_issue_id)).to match_array(epic_issues.map(&:id))
    end

    it 'does not return issues user can not see' do
      project.add_developer(user)

      expect(result.count).to eq(1)
      expect(result.map(&:id)).to match_array([issue.id])
      expect(result.map(&:epic_issue_id)).to match_array([epic_issues.first.id])
    end
  end

  describe '#close' do
    subject(:epic) { create(:epic, state: 'opened') }

    it 'sets closed_at to Time.now when an epic is closed' do
      expect { epic.close }.to change { epic.closed_at }.from(nil)
    end

    it 'changes the state to closed' do
      expect { epic.close }.to change { epic.state }.from('opened').to('closed')
    end
  end

  describe '#reopen' do
    subject(:epic) { create(:epic, state: 'closed', closed_at: Time.now, closed_by: user) }

    it 'sets closed_at to nil when an epic is reopend' do
      expect { epic.reopen }.to change { epic.closed_at }.to(nil)
    end

    it 'sets closed_by to nil when an epic is reopend' do
      expect { epic.reopen }.to change { epic.closed_by }.from(user).to(nil)
    end

    it 'changes the state to opened' do
      expect { epic.reopen }.to change { epic.state }.from('closed').to('opened')
    end
  end

  describe '#to_reference' do
    let(:group) { create(:group, path: 'group-a') }
    let(:subgroup) { create(:group) }
    let(:group_project) { create(:project, group: group) }
    let(:subgroup_project) { create(:project, group: subgroup) }
    let(:other_project) { create(:project) }
    let(:epic) { create(:epic, iid: 1, group: group) }

    context 'when nil argument' do
      it 'returns epic id' do
        expect(epic.to_reference).to eq('&1')
      end
    end

    context 'when from argument equals epic group' do
      it 'returns epic id' do
        expect(epic.to_reference(epic.group)).to eq('&1')
      end
    end

    context 'when from argument is a group different from epic group' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(create(:group))).to eq('group-a&1')
      end
    end

    context 'when from argument is a project under the epic group' do
      it 'returns epic id' do
        expect(epic.to_reference(group_project)).to eq('&1')
      end
    end

    context 'when from argument is a project under the epic subgroup' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(subgroup_project)).to eq('group-a&1')
      end
    end

    context 'when from argument is a project in another group' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(other_project)).to eq('group-a&1')
      end
    end

    context 'when full is true' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(full: true)).to             eq('group-a&1')
        expect(epic.to_reference(epic.group, full: true)).to eq('group-a&1')
        expect(epic.to_reference(group, full: true)).to      eq('group-a&1')
        expect(epic.to_reference(group_project, full: true)).to eq('group-a&1')
      end
    end
  end

  describe '#has_children?' do
    let(:epic) { create(:epic, group: group) }

    it 'has no children' do
      expect(epic.has_children?).to be_falsey
    end

    it 'has child epics' do
      create(:epic, group: group, parent: epic)

      expect(epic.reload.has_children?).to be_truthy
    end
  end

  describe '#has_issues?' do
    let(:epic) { create(:epic, group: group) }

    it 'has no issues' do
      expect(epic.has_issues?).to be_falsey
    end

    it 'has child issues' do
      create(:epic_issue, epic: epic, issue: create(:issue))

      expect(epic.has_issues?).to be_truthy
    end
  end

  context 'mentioning other objects' do
    let(:epic) { create(:epic, group: group) }

    let(:project) { create(:project, :repository, :public) }
    let(:mentioned_issue) { create(:issue, project: project) }
    let(:mentioned_mr)     { create(:merge_request, source_project: project) }
    let(:mentioned_commit) { project.commit("HEAD~1") }

    let(:backref_text) { "epic #{epic.to_reference}" }
    let(:ref_text) do
      <<-MSG.strip_heredoc
        These are simple references:
          Issue:  #{mentioned_issue.to_reference(group)}
          Merge Request:  #{mentioned_mr.to_reference(group)}
          Commit: #{mentioned_commit.to_reference(group)}

        This is a self-reference and should not be mentioned at all:
          Self: #{backref_text}
      MSG
    end

    before do
      epic.description = ref_text
      epic.save
    end

    it 'creates new system notes for cross references' do
      [mentioned_issue, mentioned_mr, mentioned_commit].each do |newref|
        expect(SystemNoteService).to receive(:cross_reference)
          .with(newref, epic, epic.author)
      end

      epic.create_new_cross_references!(epic.author)
    end
  end

  context "relative positioning" do
    it_behaves_like "a class that supports relative positioning" do
      let(:factory) { :epic }
      let(:default_params) { {} }
    end
  end

  describe '.related_issues' do
    it 'returns epic issues ordered by relative position' do
      epic1 = create(:epic, group: group)
      epic2 = create(:epic, group: group)
      issue1 = create(:issue, project: project)
      issue2 = create(:issue, project: project)
      create(:issue, project: project)
      create(:epic_issue, epic: epic1, issue: issue1, relative_position: 5)
      create(:epic_issue, epic: epic2, issue: issue2, relative_position: 2)

      result = described_class.related_issues(ids: [epic1.id, epic2.id])

      expect(result.pluck(:id)).to eq [issue2.id, issue1.id]
    end
  end

  it_behaves_like 'versioned description'
end
