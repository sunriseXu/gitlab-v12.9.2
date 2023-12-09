# frozen_string_literal: true

require 'spec_helper'

describe BasePolicy, :do_not_mock_admin_mode do
  include ExternalAuthorizationServiceHelpers

  let(:auditor) { build(:auditor) }

  subject { described_class.new(auditor, nil) }

  describe 'read cross project' do
    context 'when an external authorization service is enabled' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows auditors' do
        is_expected.to be_allowed(:read_cross_project)
      end
    end
  end

  describe 'read all resources' do
    it 'allows auditors' do
      is_expected.to be_allowed(:read_all_resources)
    end
  end
end
