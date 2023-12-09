# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestLabelAdded do
  it_behaves_like 'cycle analytics event' do
    let(:params) { { label: GroupLabel.new } }
  end
end
