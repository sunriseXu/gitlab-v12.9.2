# frozen_string_literal: true

module EE
  module PolicyActor
    def auditor?
      false
    end

    def support_bot?
      false
    end

    def visual_review_bot?
      false
    end
  end
end
