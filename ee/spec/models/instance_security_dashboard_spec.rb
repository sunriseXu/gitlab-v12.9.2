# frozen_string_literal: true

require 'spec_helper'

describe InstanceSecurityDashboard do
  let(:pipeline1) { create(:ci_pipeline, project: project1) }
  let(:pipeline2) { create(:ci_pipeline, project: project2) }
  let(:project1) { create(:project) }
  let(:project2) { create(:project) }
  let(:project_ids) { [project1.id] }
  let(:user) { create(:user) }

  before do
    project1.add_developer(user)
    user.security_dashboard_projects << [project1, project2]
  end

  subject { described_class.new(user, project_ids: project_ids) }

  describe '#all_pipelines' do
    it 'returns pipelines for the projects with security reports' do
      expect(subject.all_pipelines).to contain_exactly(pipeline1)
    end
  end

  describe '#project_ids_with_security_reports' do
    context 'when given project IDs' do
      it "returns the project IDs that are also on the user's security dashboard" do
        expect(subject.project_ids_with_security_reports).to contain_exactly(project1.id)
      end
    end

    context 'when not given project IDs' do
      let(:project_ids) { [] }

      it "returns the security dashboard projects' IDs" do
        expect(subject.project_ids_with_security_reports).to contain_exactly(project1.id)
      end
    end

    context 'when the user cannot read all resources' do
      let(:project_ids) { [project1.id, project2.id] }

      it 'only includes projects they can read' do
        expect(subject.project_ids_with_security_reports).to contain_exactly(project1.id)
      end
    end

    context 'when the user can read all resources' do
      let(:project_ids) { [project1.id, project2.id] }
      let(:user) { create(:auditor) }

      it 'includes all dashboard projects' do
        expect(subject.project_ids_with_security_reports).to contain_exactly(project1.id, project2.id)
      end
    end
  end

  describe '#feature_available?' do
    subject { described_class.new(user).feature_available?(:security_dashboard) }

    context "when the feature is available for the instance's license" do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context "when the feature is not available for the instance's license" do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns false' do
        is_expected.to be_falsy
      end
    end
  end

  describe '#projects' do
    context 'when the user cannot read all resources' do
      it 'returns only projects on their dashboard that they can read' do
        expect(subject.projects).to contain_exactly(project1)
      end
    end

    context 'when the user can read all resources' do
      let(:project_ids) { [project1.id, project2.id] }
      let(:user) { create(:auditor) }

      it "returns all projects on the user's dashboard" do
        expect(subject.projects).to contain_exactly(project1, project2)
      end
    end
  end
end
