# frozen_string_literal: true

require 'spec_helper'

describe Geo::DesignUpdatedRecentlyFinder, :geo, :geo_fdw do
  include EE::GeoHelpers

  describe '#execute' do
    let(:node) { create(:geo_node) }
    let(:group_1) { create(:group) }
    let(:group_2) { create(:group) }
    let(:nested_group_1) { create(:group, parent: group_1) }
    let!(:project_1) { create(:project, group: group_1) }
    let!(:project_2) { create(:project, group: nested_group_1) }
    let!(:project_3) { create(:project, group: group_2) }
    let!(:project_4) { create(:project, group: group_1) }

    before do
      project_4.update_column(:repository_storage, 'foo')

      create(:geo_design_registry, project: project_1)
      create(:geo_design_registry, project: project_2)
      create(:geo_design_registry, :synced, project: project_3)
      create(:geo_design_registry, project: project_4)

      create(:design, project: project_1)
      create(:design, project: project_2)
      create(:design, project: project_3)
      create(:design, project: project_4)

      stub_current_geo_node(node)
    end

    subject { described_class.new(shard_name: 'default', batch_size: 100) }

    context 'without selective sync' do
      it 'returns desings with a dirty entry on the tracking database' do
        expect(subject.execute).to match_array([project_1.id, project_2.id])
      end
    end

    context 'with selective sync by namespace' do
      it 'returns designs that belong to the namespaces with a dirty entry on the tracking database' do
        node.update!(selective_sync_type: 'namespaces', namespaces: [group_1])

        expect(subject.execute).to match_array([project_1.id, project_2.id])
      end
    end

    context 'with selective sync by shard' do
      before do
        node.update!(selective_sync_type: 'shards', selective_sync_shards: ['foo'])
      end

      it 'does not return designs out of selected shard' do
        subject = described_class.new(shard_name: 'default', batch_size: 100)

        expect(subject.execute).to be_empty
      end

      it 'returns designs that belong to the shards with a dirty entry on the tracking database' do
        project_5 = create(:project, group: group_1)
        project_5.update_column(:repository_storage, 'foo')
        create(:design, project: project_5)
        create(:geo_design_registry, :synced, project: project_5)

        subject = described_class.new(shard_name: 'foo', batch_size: 100)

        expect(subject.execute).to match_array([project_4.id])
      end
    end
  end
end
