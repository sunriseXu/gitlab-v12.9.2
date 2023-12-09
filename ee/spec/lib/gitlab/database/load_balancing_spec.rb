# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Database::LoadBalancing do
  describe '.proxy' do
    context 'when configured' do
      before do
        allow(ActiveRecord::Base.singleton_class).to receive(:prepend)
        subject.configure_proxy
      end

      after do
        subject.configure_proxy(nil)
      end

      it 'returns the connection proxy' do
        expect(subject.proxy).to be_an_instance_of(subject::ConnectionProxy)
      end
    end

    context 'when not configured' do
      it 'returns nil' do
        expect(subject.proxy).to be_nil
      end

      it 'tracks an error to sentry' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(subject::ProxyNotConfiguredError)
        )

        subject.proxy
      end
    end
  end

  describe '.configuration' do
    it 'returns a Hash' do
      config = { 'hosts' => %w(foo) }

      allow(ActiveRecord::Base.configurations[Rails.env])
        .to receive(:[])
        .with('load_balancing')
        .and_return(config)

      expect(described_class.configuration).to eq(config)
    end
  end

  describe '.max_replication_difference' do
    context 'without an explicitly configured value' do
      it 'returns the default value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({})

        expect(described_class.max_replication_difference).to eq(8.megabytes)
      end
    end

    context 'with an explicitly configured value' do
      it 'returns the configured value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({ 'max_replication_difference' => 4 })

        expect(described_class.max_replication_difference).to eq(4)
      end
    end
  end

  describe '.max_replication_lag_time' do
    context 'without an explicitly configured value' do
      it 'returns the default value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({})

        expect(described_class.max_replication_lag_time).to eq(60)
      end
    end

    context 'with an explicitly configured value' do
      it 'returns the configured value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({ 'max_replication_lag_time' => 4 })

        expect(described_class.max_replication_lag_time).to eq(4)
      end
    end
  end

  describe '.replica_check_interval' do
    context 'without an explicitly configured value' do
      it 'returns the default value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({})

        expect(described_class.replica_check_interval).to eq(60)
      end
    end

    context 'with an explicitly configured value' do
      it 'returns the configured value' do
        allow(described_class)
          .to receive(:configuration)
          .and_return({ 'replica_check_interval' => 4 })

        expect(described_class.replica_check_interval).to eq(4)
      end
    end
  end

  describe '.hosts' do
    it 'returns a list of hosts' do
      allow(described_class)
        .to receive(:configuration)
        .and_return({ 'hosts' => %w(foo bar baz) })

      expect(described_class.hosts).to eq(%w(foo bar baz))
    end
  end

  describe '.pool_size' do
    it 'returns a Fixnum' do
      expect(described_class.pool_size).to be_a_kind_of(Integer)
    end
  end

  describe '.enable?' do
    let!(:license) { create(:license, plan: ::License::PREMIUM_PLAN) }

    it 'returns false when no hosts are specified' do
      allow(described_class).to receive(:hosts).and_return([])

      expect(described_class.enable?).to eq(false)
    end

    it 'returns false when Sidekiq is being used' do
      allow(described_class).to receive(:hosts).and_return(%w(foo))
      allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(true)

      expect(described_class.enable?).to eq(false)
    end

    it 'returns false when running inside a Rake task' do
      expect(described_class).to receive(:program_name).and_return('rake')

      expect(described_class.enable?).to eq(false)
    end

    it 'returns true when load balancing should be enabled' do
      allow(described_class).to receive(:hosts).and_return(%w(foo))
      allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(false)

      expect(described_class.enable?).to eq(true)
    end

    it 'returns true when service discovery is enabled' do
      allow(described_class).to receive(:hosts).and_return([])
      allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(false)

      allow(described_class)
        .to receive(:service_discovery_enabled?)
        .and_return(true)

      expect(described_class.enable?).to eq(true)
    end

    context 'without a license' do
      before do
        License.destroy_all # rubocop: disable DestroyAll
      end

      it 'is disabled' do
        expect(described_class.enable?).to eq(false)
      end
    end

    context 'with an EES license' do
      let!(:license) { create(:license, plan: ::License::STARTER_PLAN) }

      it 'is disabled' do
        expect(described_class.enable?).to eq(false)
      end
    end

    context 'with an EEP license' do
      let!(:license) { create(:license, plan: ::License::PREMIUM_PLAN) }

      it 'is enabled' do
        allow(described_class).to receive(:hosts).and_return(%w(foo))
        allow(Gitlab::Runtime).to receive(:sidekiq?).and_return(false)

        expect(described_class.enable?).to eq(true)
      end
    end
  end

  describe '.program_name' do
    it 'returns a String' do
      expect(described_class.program_name).to be_an_instance_of(String)
    end
  end

  describe '.configure_proxy' do
    after do
      described_class.configure_proxy(nil)
    end

    it 'configures the connection proxy' do
      allow(ActiveRecord::Base.singleton_class).to receive(:prepend)

      described_class.configure_proxy

      expect(ActiveRecord::Base.singleton_class).to have_received(:prepend)
        .with(Gitlab::Database::LoadBalancing::ActiveRecordProxy)
    end
  end

  describe '.active_record_models' do
    it 'returns an Array' do
      expect(described_class.active_record_models).to be_an_instance_of(Array)
    end
  end

  describe '.service_discovery_enabled?' do
    it 'returns true if service discovery is enabled' do
      allow(described_class)
        .to receive(:configuration)
        .and_return('discover' => { 'record' => 'foo' })

      expect(described_class.service_discovery_enabled?).to eq(true)
    end

    it 'returns false if service discovery is disabled' do
      expect(described_class.service_discovery_enabled?).to eq(false)
    end
  end

  describe '.service_discovery_configuration' do
    context 'when no configuration is provided' do
      it 'returns a default configuration Hash' do
        expect(described_class.service_discovery_configuration).to eq(
          nameserver: 'localhost',
          port: 8600,
          record: nil,
          record_type: 'A',
          interval: 60,
          disconnect_timeout: 120,
          use_tcp: false
        )
      end
    end

    context 'when configuration is provided' do
      it 'returns a Hash including the custom configuration' do
        allow(described_class)
          .to receive(:configuration)
          .and_return('discover' => { 'record' => 'foo', 'record_type' => 'SRV' })

        expect(described_class.service_discovery_configuration).to eq(
          nameserver: 'localhost',
          port: 8600,
          record: 'foo',
          record_type: 'SRV',
          interval: 60,
          disconnect_timeout: 120,
          use_tcp: false
        )
      end
    end
  end

  describe '.start_service_discovery' do
    it 'does not start if service discovery is disabled' do
      expect(Gitlab::Database::LoadBalancing::ServiceDiscovery)
        .not_to receive(:new)

      described_class.start_service_discovery
    end

    it 'starts service discovery if enabled' do
      allow(described_class)
        .to receive(:service_discovery_enabled?)
        .and_return(true)

      instance = double(:instance)

      expect(Gitlab::Database::LoadBalancing::ServiceDiscovery)
        .to receive(:new)
        .with(an_instance_of(Hash))
        .and_return(instance)

      expect(instance)
        .to receive(:start)

      described_class.start_service_discovery
    end
  end
end
