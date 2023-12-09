# frozen_string_literal: true

require 'spec_helper'

describe InstanceClusterablePresenter do
  include Gitlab::Routing.url_helpers

  let(:presenter) { described_class.new(instance) }
  let(:cluster) { create(:cluster, :provided_by_gcp, :instance) }
  let(:instance) { cluster.instance }

  describe '#metrics_cluster_path' do
    subject { presenter.metrics_cluster_path(cluster) }

    it { is_expected.to eq(metrics_admin_cluster_path(cluster)) }
  end

  describe '#metrics_dashboard_path' do
    subject { presenter.metrics_dashboard_path(cluster) }

    it { is_expected.to eq(metrics_dashboard_admin_cluster_path(cluster)) }
  end
end
