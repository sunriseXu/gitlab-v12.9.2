# frozen_string_literal: true

module EE
  module GroupMilestone
    def supports_weight?
      group&.feature_available?(:issue_weights)
    end
  end
end
