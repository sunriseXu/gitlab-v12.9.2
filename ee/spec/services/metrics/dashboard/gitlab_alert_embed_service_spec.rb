# frozen_string_literal: true

require 'spec_helper'

describe Metrics::Dashboard::GitlabAlertEmbedService do
  include MetricsDashboardHelpers

  let_it_be(:alert) { create(:prometheus_alert) }
  let_it_be(:project) { alert.project }
  let_it_be(:user) { create(:user) }
  let(:alert_id) { alert.id }

  before do
    project.add_maintainer(user)
    project.clear_memoization(:licensed_feature_available)
  end

  describe '.valid_params?' do
    let(:valid_params) do
      {
        embedded: true,
        prometheus_alert_id: alert_id
      }
    end

    subject { described_class.valid_params?(params) }

    let(:params) { valid_params }

    it { is_expected.to be_truthy }

    context 'missing embedded' do
      let(:params) { valid_params.except(:embedded) }

      it { is_expected.to be_falsey }
    end

    context 'not embedded' do
      let(:params) { valid_params.merge(embedded: 'false') }

      it { is_expected.to be_falsey }
    end

    context 'missing alert id' do
      let(:params) { valid_params.except(:prometheus_alert_id) }

      it { is_expected.to be_falsey }
    end

    context 'missing alert id' do
      let(:params) { valid_params.merge(prometheus_alert_id: 'none') }

      it { is_expected.to be_falsey }
    end
  end

  describe '#get_dashboard' do
    let(:service_params) do
      [
        project,
        user,
        {
          embedded: true,
          prometheus_alert_id: alert_id
        }
      ]
    end

    let(:service_call) { described_class.new(*service_params).get_dashboard }

    it_behaves_like 'misconfigured dashboard service response', :unauthorized

    context 'when alerting is available' do
      before do
        stub_licensed_features(prometheus_alerts: true)
      end

      it_behaves_like 'valid embedded dashboard service response'
      it_behaves_like 'raises error for users with insufficient permissions'

      it 'uses the metric info corresponding to the alert' do
        result = service_call
        metrics = result[:dashboard][:panel_groups][0][:panels][0][:metrics]

        expect(metrics.length).to eq 1
        expect(metrics.first[:metric_id]).to eq alert.prometheus_metric_id
      end

      context 'when the metric does not exist' do
        let(:alert_id) { -4 }

        it_behaves_like 'misconfigured dashboard service response', :not_found
      end

      it 'does not cache the unprocessed dashboard' do
        expect(Gitlab::Metrics::Dashboard::Cache).not_to receive(:fetch)

        described_class.new(*service_params).get_dashboard
      end
    end
  end
end
