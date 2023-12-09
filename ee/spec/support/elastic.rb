# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, :elastic) do
    Elastic::ProcessBookkeepingService.clear_tracking!
    Gitlab::Elastic::Helper.create_empty_index
  end

  config.after(:each, :elastic) do
    Gitlab::Elastic::Helper.delete_index
    Elastic::ProcessBookkeepingService.clear_tracking!
  end

  config.include ElasticsearchHelpers, :elastic
end
