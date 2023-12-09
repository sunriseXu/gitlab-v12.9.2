# frozen_string_literal: true

require 'spec_helper'

describe 'accessing the analytics workspace' do
  include AnalyticsHelpers
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'renders the productivity analytics landing page' do
    stub_licensed_features(Gitlab::Analytics::PRODUCTIVITY_ANALYTICS_FEATURE_FLAG => true)

    visit analytics_root_path

    expect(page.status_code).to eq(200)
  end
end
