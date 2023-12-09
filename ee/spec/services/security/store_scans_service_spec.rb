# frozen_string_literal: true

require 'spec_helper'

describe Security::StoreScansService do
  let(:build) { create(:ci_build) }

  subject { Security::StoreScansService.new(build).execute }

  context 'build has security reports' do
    before do
      create(:ee_ci_job_artifact, :dast, job: build)
      create(:ee_ci_job_artifact, :sast, job: build)
      create(:ee_ci_job_artifact, :codequality, job: build)
    end

    it 'saves security scans' do
      subject

      scans = Security::Scan.where(build: build)
      expect(scans.count).to be(2)
      expect(scans.sast.count).to be(1)
      expect(scans.dast.count).to be(1)
    end
  end

  context 'scan already exists' do
    before do
      create(:ee_ci_job_artifact, :dast, job: build)
      create(:security_scan, build: build, scan_type: 'dast')
    end

    it 'does not save' do
      subject

      expect(Security::Scan.where(build: build).count).to be(1)
    end
  end
end
