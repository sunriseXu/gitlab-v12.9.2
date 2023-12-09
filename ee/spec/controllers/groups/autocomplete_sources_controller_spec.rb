# frozen_string_literal: true

require 'spec_helper'

describe Groups::AutocompleteSourcesController do
  let(:user) { create(:user) }
  let(:group) { create(:group, :private) }
  let!(:epic) { create(:epic, group: group) }

  before do
    group.add_developer(user)
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe '#epics' do
    it 'returns 200 status' do
      get :epics, params: { group_id: group }

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'returns the correct response' do
      get :epics, params: { group_id: group }

      expect(json_response).to be_an(Array)
      expect(json_response.first).to include(
        'iid' => epic.iid, 'title' => epic.title
      )
    end
  end

  describe '#milestones' do
    it 'returns correct response' do
      parent_group = create(:group, :private)
      group.update!(parent: parent_group)
      sub_group = create(:group, :private, parent: sub_group)
      create(:milestone, group: parent_group)
      create(:milestone, group: sub_group)
      group_milestone = create(:milestone, group: group)

      get :milestones, params: { group_id: group }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.count).to eq(1)
      expect(json_response.first).to include(
        'iid' => group_milestone.iid, 'title' => group_milestone.title
      )
    end
  end

  describe '#commands' do
    it 'returns 200 status' do
      get :commands, params: { group_id: group, type: 'Epic', type_id: epic.iid }

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'returns the correct response' do
      get :commands, params: { group_id: group, type: 'Epic', type_id: epic.iid }

      expect(json_response).to be_an(Array)
      expect(json_response).to include(
        {
          'name' => 'close', 'aliases' => [], 'description' => 'Close this epic',
          'params' => [], 'warning' => '', 'icon' => ''
        }
      )
    end
  end
end
