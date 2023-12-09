# frozen_string_literal: true

require 'spec_helper'

describe GroupProjectsFinder do
  include_context 'GroupProjectsFinder context'

  subject { finder.execute }

  describe 'with an auditor current user' do
    let(:current_user) { create(:user, :auditor) }

    context 'only shared' do
      let(:options) { { only_shared: true } }

      it { is_expected.to eq([shared_project_3, shared_project_2, shared_project_1]) }
    end

    context 'only owned' do
      let(:options) { { only_owned: true } }

      it { is_expected.to eq([private_project, public_project]) }
    end

    context 'all' do
      subject { described_class.new(group: group, current_user: current_user).execute }

      it { is_expected.to eq([shared_project_3, shared_project_2, shared_project_1, private_project, public_project]) }
    end
  end

  describe "group's projects with security reports" do
    let(:params) { { with_security_reports: true } }
    let(:project_with_reports) { create(:project, :public, group: group) }
    let!(:project_without_reports) { create(:project, :public, group: group) }

    before do
      create(:ee_ci_job_artifact, :sast, project: project_with_reports)
    end

    context 'when security dashboard is enabled for a group' do
      let(:group) { create(:group, plan: :gold_plan) } # overriding group from 'GroupProjectsFinder context'

      before do
        stub_licensed_features(security_dashboard: true)
        enable_namespace_license_check!

        create(:gitlab_subscription, hosted_plan: group.plan, namespace: group)
      end

      it { is_expected.to contain_exactly(project_with_reports) }
    end

    context 'when security dashboard is disabled for a group' do
      let(:project_with_reports) { create(:project, :public, group: group) }

      # using `include` since other projects may be added to this group from different contexts
      it { is_expected.to include(project_with_reports, project_without_reports) }
    end
  end
end
