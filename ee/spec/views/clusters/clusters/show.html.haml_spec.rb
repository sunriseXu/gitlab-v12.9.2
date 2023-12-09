# frozen_string_literal: true

require 'spec_helper'

describe 'clusters/clusters/show' do
  let_it_be(:user) { create(:user) }

  shared_examples 'cluster health section' do
    let(:cluster_presenter) { cluster.present(current_user: user) }

    let(:clusterable_presenter) do
      ClusterablePresenter.fabricate(clusterable, current_user: user)
    end

    before do
      assign(:cluster, cluster_presenter)
      allow(view).to receive(:clusterable).and_return(clusterable_presenter)
    end

    context 'with feature cluster_health available' do
      before do
        stub_licensed_features(cluster_health: true)
      end

      it 'displays the Cluster health section' do
        render

        expect(rendered).to have_selector('#cluster-health-tab')
        expect(rendered).to have_content('Health')
      end
    end

    context 'without feature cluster_health available' do
      before do
        stub_licensed_features(cluster_health: false)
      end

      it 'does not show the Cluster health section' do
        render

        expect(rendered).not_to have_selector('#cluster-health')
        expect(rendered).not_to have_content('Cluster health')
      end
    end
  end

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  context 'when the cluster details page is opened' do
    context 'with project level cluster' do
      let(:cluster) { create(:cluster, :project, :provided_by_gcp) }
      let(:clusterable) { cluster.project }

      it_behaves_like 'cluster health section'
    end

    context 'with group level cluster' do
      let(:cluster) { create(:cluster, :group, :provided_by_gcp) }
      let(:clusterable) { cluster.group }

      it_behaves_like 'cluster health section'
    end
  end
end
