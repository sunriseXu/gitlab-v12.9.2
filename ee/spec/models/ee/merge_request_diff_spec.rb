# frozen_string_literal: true

require 'spec_helper'

describe MergeRequestDiff do
  it { is_expected.to respond_to(:log_geo_deleted_event) }
end
