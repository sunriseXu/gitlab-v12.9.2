# frozen_string_literal: true

require 'spec_helper'

describe FeatureFlags::DestroyService do
  include FeatureFlagHelpers

  let(:project) { create(:project) }
  let(:developer) { create(:user) }
  let(:reporter) { create(:user) }
  let(:user) { developer }
  let!(:feature_flag) { create(:operations_feature_flag, project: project) }

  before do
    stub_licensed_features(feature_flags: true)
    project.add_developer(developer)
    project.add_reporter(reporter)
  end

  describe '#execute' do
    subject { described_class.new(project, user, params).execute(feature_flag) }

    let(:audit_event_message) { AuditEvent.last.present.action }
    let(:params) { {} }

    it 'returns status success' do
      expect(subject[:status]).to eq(:success)
    end

    it 'destroys feature flag' do
      expect { subject }.to change { Operations::FeatureFlag.count }.by(-1)
    end

    it 'creates audit log' do
      expect { subject }.to change { AuditEvent.count }.by(1)
      expect(audit_event_message).to eq("Deleted feature flag <strong>#{feature_flag.name}</strong>.")
    end

    context 'when user is reporter' do
      let(:user) { reporter }

      it 'returns error status' do
        expect(subject[:status]).to eq(:error)
        expect(subject[:message]).to eq('Access Denied')
      end
    end

    context 'when feature flag can not be destroyed' do
      before do
        allow(feature_flag).to receive(:destroy).and_return(false)
      end

      it 'returns status error' do
        expect(subject[:status]).to eq(:error)
      end

      it 'does not create audit log' do
        expect { subject }.not_to change { AuditEvent.count }
      end
    end
  end
end
