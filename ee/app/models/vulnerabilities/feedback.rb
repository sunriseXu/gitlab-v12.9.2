# frozen_string_literal: true

module Vulnerabilities
  class Feedback < ApplicationRecord
    self.table_name = 'vulnerability_feedback'

    belongs_to :project
    belongs_to :author, class_name: 'User'
    belongs_to :issue
    belongs_to :merge_request
    belongs_to :pipeline, class_name: 'Ci::Pipeline', foreign_key: :pipeline_id

    belongs_to :comment_author, class_name: 'User'

    attr_accessor :vulnerability_data

    enum feedback_type: { dismissal: 0, issue: 1, merge_request: 2 }, _prefix: :for
    enum category: { sast: 0, dependency_scanning: 1, container_scanning: 2, dast: 3 }

    validates :project, presence: true
    validates :author, presence: true
    validates :comment_timestamp, :comment_author, presence: true, if: :comment?
    validates :issue, presence: true, if: :for_issue?
    validates :merge_request, presence: true, if: :for_merge_request?
    validates :vulnerability_data, presence: true, unless: :for_dismissal?
    validates :feedback_type, presence: true
    validates :category, presence: true
    validates :project_fingerprint, presence: true, uniqueness: { scope: [:project_id, :category, :feedback_type] }
    validates :pipeline, same_project_association: true, if: :pipeline_id?

    scope :with_associations, -> { includes(:pipeline, :issue, :merge_request, :author, :comment_author) }

    scope :all_preloaded, -> do
      preload(:author, :comment_author, :project, :issue, :merge_request, :pipeline)
    end

    # TODO remove once filtered data has been cleaned
    def self.only_valid_feedback
      pipeline = Ci::Pipeline.arel_table
      feedback = arel_table
      joins(:pipeline).where(pipeline[:project_id].eq(feedback[:project_id]))
    end

    def self.find_or_init_for(feedback_params)
      validate_enums(feedback_params)

      record = find_or_initialize_by(feedback_params.slice(:category, :feedback_type, :project_fingerprint))
      record.assign_attributes(feedback_params)
      record
    end

    # Rails 5.0 does not properly handle validation of enums in select queries such as find_or_initialize_by.
    # This method, and calls to it can be removed when we are on Rails 5.2.
    def self.validate_enums(feedback_params)
      unless feedback_types.include?(feedback_params[:feedback_type])

        raise ArgumentError.new("'#{feedback_params[:feedback_type]}' is not a valid feedback_type")
      end

      unless categories.include?(feedback_params[:category])
        raise ArgumentError.new("'#{feedback_params[:category]}' is not a valid category")
      end
    end

    def self.with_category(category)
      where(category: category)
    end

    def self.with_feedback_type(feedback_type)
      where(feedback_type: feedback_type)
    end

    # A hard delete of the comment_author will cause the comment_author to be nil, but the comment
    # will still exist.
    def has_comment?
      comment.present? && comment_author.present?
    end
  end
end
