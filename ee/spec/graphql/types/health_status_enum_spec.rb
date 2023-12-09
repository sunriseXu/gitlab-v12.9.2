# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['HealthStatus'] do
  it { expect(described_class.graphql_name).to eq('HealthStatus') }

  it 'exposes all the existing epic sort orders' do
    expect(described_class.values.keys).to include(*%w[onTrack needsAttention atRisk])
  end
end