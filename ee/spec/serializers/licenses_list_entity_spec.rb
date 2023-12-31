# frozen_string_literal: true

require 'spec_helper'

describe LicensesListEntity do
  let!(:pipeline) { create(:ee_ci_pipeline, :with_license_management_report, project: project) }
  let(:license_compliance) { ::SCA::LicenseCompliance.new(project) }

  before do
    stub_licensed_features(license_management: true)
  end

  it_behaves_like 'report list' do
    let(:name) { :licenses }
    let(:collection) { license_compliance.policies }
    let(:no_items_status) { :no_licenses }
  end
end
