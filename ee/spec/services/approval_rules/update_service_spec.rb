# frozen_string_literal: true

require 'spec_helper'

describe ApprovalRules::UpdateService do
  let(:project) { create(:project) }
  let(:user) { project.creator }
  let(:approval_rule) { target.approval_rules.create(name: 'foo', approvals_required: 2) }

  shared_examples 'editable' do
    let(:new_approvers) { create_list(:user, 2) }
    let(:new_groups) { create_list(:group, 2, :private) }

    it 'updates approval, excluding non-eligible users and groups' do
      result = described_class.new(approval_rule, user, {
        name: 'security',
        approvals_required: 1,
        user_ids: new_approvers.map(&:id),
        group_ids: new_groups.map(&:id)
      }).execute

      expect(result[:status]).to eq(:success)

      rule = result[:rule]

      expect(rule.name).to eq('security')
      expect(rule.approvals_required).to eq(1)
      expect(rule.users).to be_empty
      expect(rule.groups).to be_empty
    end

    context 'when some users and groups are eligible' do
      before do
        project.add_reporter new_approvers.first
        new_groups.first.add_guest user
      end

      it 'creates and includes eligible users and groups' do
        result = described_class.new(approval_rule, user, {
          name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id)
        }).execute

        expect(result[:status]).to eq(:success)

        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to contain_exactly(new_approvers.first)
        expect(rule.groups).to contain_exactly(new_groups.first)
      end
    end

    context 'when existing groups are inaccessible to user' do
      let(:private_accessible_group) { create(:group, :private) }
      let(:private_inaccessible_group) { create(:group, :private) }
      let(:new_group) { create(:group) }

      before do
        approval_rule.groups = [private_accessible_group, private_inaccessible_group]
        private_accessible_group.add_guest user
      end

      context 'when remove_hidden_groups is false' do
        it 'preserves inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            remove_hidden_groups: false,
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(private_inaccessible_group, new_group)
        end
      end

      context 'when remove_hidden_groups is not specified' do
        it 'removes inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(private_inaccessible_group, new_group)
        end
      end

      context 'when remove_hidden_groups is true' do
        it 'removes inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            remove_hidden_groups: true,
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(new_group)
        end
      end
    end

    context 'when validation fails' do
      it 'returns error message' do
        result = described_class.new(approval_rule, user, {
          name: nil,
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
      end
    end

    context 'when user does not have right to edit' do
      let(:user) { create(:user) }

      it 'returns error message' do
        result = described_class.new(approval_rule, user, {
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Prohibited')
      end
    end
  end

  context 'when target is project' do
    let(:target) { project }

    it_behaves_like "editable"

    context 'when protected_branch_ids param is present' do
      let(:protected_branch) { create(:protected_branch, project: target) }

      subject do
        described_class.new(
          approval_rule,
          user,
          protected_branch_ids: [protected_branch.id]
        ).execute
      end

      context 'and multiple approval rules is enabled' do
        before do
          stub_licensed_features(multiple_approval_rules: true)
        end

        it 'associates the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to eq([protected_branch])
        end

        context 'but user cannot administer project' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_project, target).and_return(false)
          end

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end

        context 'but protected branch is for another project' do
          let(:another_project) { create(:project) }
          let(:protected_branch) { create(:protected_branch, project: another_project) }

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end
      end

      context 'and multiple approval rules is disabled' do
        it 'does not associate the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to be_empty
        end
      end
    end

    describe 'audit events' do
      subject(:operation) do
        described_class.new(
          approval_rule,
          user,
          name: 'developers',
          approvals_required: 1
        ).execute
      end

      context 'when licensed' do
        before do
          stub_licensed_features(audit_events: true)
        end

        context 'when rule update operation succeeds' do
          it 'logs an audit event' do
            expect { operation }.to change { AuditEvent.count }.by(1)
          end

          it 'logs the audit event info' do
            operation

            expect(AuditEvent.last).to have_attributes(
              details: hash_including(change: 'number of required approvals', from: 2, to: 1)
            )
          end
        end

        context 'when rule update operation fails' do
          before do
            allow(approval_rule).to receive(:update).and_return(false)
          end

          it 'does not log any audit event' do
            expect { operation }.not_to change { AuditEvent.count }
          end
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(
            admin_audit_log: false,
            audit_events: false,
            extended_audit_events: false
          )
        end

        it 'does not log any audit event' do
          expect { operation }.not_to change { AuditEvent.count }
        end
      end
    end
  end

  context 'when target is merge request' do
    let(:target) { create(:merge_request, source_project: project, target_project: project) }

    it_behaves_like "editable"
  end
end
