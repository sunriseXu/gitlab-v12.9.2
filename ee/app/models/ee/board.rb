# frozen_string_literal: true

module EE
  module Board
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    # Empty state for milestones and weights.
    EMPTY_SCOPE_STATE = [nil, -1].freeze

    prepended do
      belongs_to :milestone

      has_many :board_labels

      # These can safely be changed to has_many when we support
      # multiple assignees on the board configuration.
      # https://gitlab.com/gitlab-org/gitlab/issues/3786
      has_one :board_assignee
      has_one :assignee, through: :board_assignee

      has_many :labels, through: :board_labels

      validates :name, presence: true

      scope :with_associations, -> { preload(:destroyable_lists, :labels, :assignee) }
    end

    override :scoped?
    def scoped?
      return super unless resource_parent.feature_available?(:scoped_issue_board)

      EMPTY_SCOPE_STATE.exclude?(milestone_id) ||
        EMPTY_SCOPE_STATE.exclude?(weight) ||
        labels.any? ||
        assignee.present?
    end

    def milestone
      return unless resource_parent&.feature_available?(:scoped_issue_board)

      case milestone_id
      when ::Milestone::Upcoming.id
        ::Milestone::Upcoming
      when ::Milestone::Started.id
        ::Milestone::Started
      else
        super
      end
    end
  end
end
