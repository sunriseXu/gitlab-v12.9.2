# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['IssueSort'] do
  it { expect(described_class.graphql_name).to eq('IssueSort') }

  it_behaves_like 'common sort values'

  it 'exposes all the existing EE issue sort values' do
    expect(described_class.values.keys).to include(*%w[WEIGHT_ASC WEIGHT_DESC])
  end
end
