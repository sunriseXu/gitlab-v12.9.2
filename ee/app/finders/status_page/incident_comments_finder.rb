# frozen_string_literal: true
#
# Retrieves Notes specifically for the Status Page
# which are rendered as comments.
#
# Arguments:
#   issue - The notes are scoped to this issue
#
# Examples:
#
#     finder = StatusPage::IncidentCommentsFinder.new(issue: issue)
#
#     # Latest, visible 100 notes
#     notes = finder.all
#
module StatusPage
  class IncidentCommentsFinder
    # Only comments with this emoji are visible.
    # This filter will change once we have confidential notes.
    # See https://gitlab.com/gitlab-org/gitlab/issues/207468
    AWARD_EMOJI = 'microphone'

    MAX_LIMIT = StatusPage::Storage::MAX_COMMENTS

    def initialize(issue:)
      @issue = issue
    end

    def all
      execute
        .limit(MAX_LIMIT) # rubocop: disable CodeReuse/ActiveRecord
    end

    private

    attr_reader :issue

    def execute
      notes = init_collection
      notes = only_user(notes)
      notes = to_publish(notes)
      notes = chronological(notes)
      notes
    end

    def init_collection
      issue.notes
    end

    def only_user(notes)
      notes.user
    end

    def to_publish(notes)
      # Instead of adding a scope Awardable#for_award_emoji_name we're inlining
      # this because this query very specific to our use-case and
      # we don't want to promote this query to other folks.
      #
      # Note 1: This finder is used by services which are currently behind a
      # beta feature flag.
      #
      # Note 2: We will switch to private comments once it's available
      # (https://gitlab.com/groups/gitlab-org/-/epics/2697)
      # rubocop: disable CodeReuse/ActiveRecord
      notes
        .joins(:award_emoji)
        .where(award_emoji: { name: AWARD_EMOJI })
      # rubocop: enable CodeReuse/ActiveRecord
    end

    def chronological(notes)
      notes.fresh
    end
  end
end
