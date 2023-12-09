# frozen_string_literal: true

require 'spec_helper'

describe 'Updating an epic tree' do
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, group: group) }
  let(:base_epic) { create(:epic, group: group) }
  let(:epic1) { create(:epic, group: group, parent: base_epic, relative_position: 10) }
  let(:epic2) { create(:epic, group: group, parent: base_epic, relative_position: 20) }
  let(:issue1) { create(:issue, project: project) }
  let(:issue2) { create(:issue, project: project) }
  let(:epic_issue1) { create(:epic_issue, epic: base_epic, issue: issue1, relative_position: 10)}
  let(:epic_issue2) { create(:epic_issue, epic: base_epic, issue: issue2, relative_position: 20)}

  let(:mutation) do
    graphql_mutation(:epic_tree_reorder, variables)
  end

  let(:relative_position) { :after }
  let(:variables) do
    {
      base_epic_id: GitlabSchema.id_from_object(base_epic).to_s,
      moved: {
        id: GitlabSchema.id_from_object(epic2).to_s,
        adjacent_reference_id: GitlabSchema.id_from_object(epic1).to_s,
        relative_position: relative_position
      }
    }
  end

  def mutation_response
    graphql_mutation_response(:epic_tree_reorder)
  end

  shared_examples 'a mutation that does not update the tree' do
    it 'does not change relative_positions' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(epic1.reload.relative_position).to eq(10)
      expect(epic2.reload.relative_position).to eq(20)
      expect(epic_issue1.reload.relative_position).to eq(10)
      expect(epic_issue2.reload.relative_position).to eq(20)
    end
  end

  context 'when epic feature is enabled' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that does not update the tree'

      it 'returns the error message' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to eq(['You don\'t have permissions to move the objects.'])
      end
    end

    context 'when the user has permission' do
      before do
        group.add_developer(current_user)
      end

      context 'when moving an epic' do
        context 'when moving an epic is successful' do
          it 'updates the epics relative positions' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(epic1.reload.relative_position).to be > epic2.reload.relative_position
          end

          it 'returns nil in errors' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['array']).to be_nil
          end
        end

        context 'when relative_position is invalid' do
          let(:relative_position) { :invalid }

          before do
            post_graphql_mutation(mutation, current_user: current_user)
          end

          it_behaves_like 'a mutation that returns top-level errors',
                          errors: ['Variable epicTreeReorderInput of type EpicTreeReorderInput! was provided invalid value for moved.relativePosition (Expected "invalid" to be one of: before, after)']
        end

        context 'when object being moved is not supported type' do
          before do
            variables[:moved][:id] = GitlabSchema.id_from_object(issue1).to_s
            variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(issue2).to_s
          end

          it 'returns the error message' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['errors']).to eq(['Only epics and epic_issues are supported.'])
          end
        end

        context 'when moving an epic fails due to another parent' do
          let(:epic2) { create(:epic, relative_position: 20) }

          it_behaves_like 'a mutation that does not update the tree'

          it 'returns the error message' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(mutation_response['errors']).to eq(['Both objects have to belong to the same parent epic.'])
          end
        end
      end

      context 'when moving an issue' do
        before do
          variables[:moved][:id] = GitlabSchema.id_from_object(epic_issue2).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue1).to_s
        end

        it 'updates the epics relative positions' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(epic_issue1.reload.relative_position).to be > epic_issue2.reload.relative_position
        end

        it 'returns nil in errors' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['array']).to be_nil
        end
      end

      context 'when moving an issue fails due to another parent' do
        let(:epic_issue2) { create(:epic_issue, relative_position: 20) }

        before do
          variables[:moved][:id] = GitlabSchema.id_from_object(epic_issue2).to_s
          variables[:moved][:adjacent_reference_id] = GitlabSchema.id_from_object(epic_issue1).to_s
        end

        it_behaves_like 'a mutation that does not update the tree'

        it 'returns the error message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors']).to eq(['Both objects have to belong to the same parent epic.'])
        end
      end
    end
  end
end
