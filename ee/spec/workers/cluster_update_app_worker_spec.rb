# frozen_string_literal: true

require 'spec_helper'

describe ClusterUpdateAppWorker do
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }

  let(:prometheus_update_service) { spy }

  subject { described_class.new }

  around do |example|
    Timecop.freeze(Time.now) { example.run }
  end

  before do
    allow(::Clusters::Applications::PrometheusUpdateService).to receive(:new).and_return(prometheus_update_service)
  end

  describe '#perform' do
    context 'when the application last_update_started_at is higher than the time the job was scheduled in' do
      it 'does nothing' do
        application = create(:clusters_applications_prometheus, :updated, last_update_started_at: Time.now)

        expect(prometheus_update_service).not_to receive(:execute)

        expect(subject.perform(application.name, application.id, project.id, Time.now - 5.minutes)).to be_nil
      end
    end

    context 'when another worker is already running' do
      it 'returns nil' do
        application = create(:clusters_applications_prometheus, :updating)

        expect(subject.perform(application.name, application.id, project.id, Time.now)).to be_nil
      end
    end

    it 'executes PrometheusUpdateService' do
      application = create(:clusters_applications_prometheus, :installed)

      expect(prometheus_update_service).to receive(:execute)

      subject.perform(application.name, application.id, project.id, Time.now)
    end

    context 'with exclusive lease' do
      let(:application) { create(:clusters_applications_prometheus, :installed) }
      let(:lease_key) { "#{described_class.name.underscore}-#{application.id}" }

      before do
        allow(Gitlab::ExclusiveLease).to receive(:new)
        stub_exclusive_lease_taken(lease_key)
      end

      it 'does not allow same app to be updated concurrently by same project' do
        expect(Clusters::Applications::PrometheusUpdateService).not_to receive(:new)

        subject.perform(application.name, application.id, project.id, Time.now)
      end

      it 'does not allow same app to be updated concurrently by different project' do
        project1 = create(:project)

        expect(Clusters::Applications::PrometheusUpdateService).not_to receive(:new)

        subject.perform(application.name, application.id, project1.id, Time.now)
      end

      it 'allows different app to be updated concurrently by same project' do
        application2 = create(:clusters_applications_prometheus, :installed)
        lease_key2 = "#{described_class.name.underscore}-#{application2.id}"

        stub_exclusive_lease(lease_key2)

        expect(Clusters::Applications::PrometheusUpdateService).to receive(:new)
          .with(application2, project)

        subject.perform(application2.name, application2.id, project.id, Time.now)
      end

      it 'allows different app to be updated by different project' do
        application2 = create(:clusters_applications_prometheus, :installed)
        lease_key2 = "#{described_class.name.underscore}-#{application2.id}"
        project2 = create(:project)

        stub_exclusive_lease(lease_key2)

        expect(Clusters::Applications::PrometheusUpdateService).to receive(:new)
          .with(application2, project2)

        subject.perform(application2.name, application2.id, project2.id, Time.now)
      end
    end
  end
end
