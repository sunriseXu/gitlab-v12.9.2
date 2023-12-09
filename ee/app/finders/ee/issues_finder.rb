# frozen_string_literal: true

module EE
  module IssuesFinder
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    class_methods do
      extend ::Gitlab::Utils::Override

      override :scalar_params
      def scalar_params
        @scalar_params ||= super + [:weight, :epic_id]
      end
    end

    override :filter_items
    def filter_items(items)
      issues = by_weight(super)
      by_epic(issues)
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def by_weight(items)
      return items unless weights?

      if filter_by_no_weight?
        items.where(weight: [-1, nil])
      elsif filter_by_any_weight?
        items.where.not(weight: [-1, nil])
      else
        items.where(weight: params[:weight])
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def weights?
      params[:weight].present? && params[:weight] != ::Issue::WEIGHT_ALL
    end

    def filter_by_no_weight?
      params[:weight].to_s.downcase == ::IssuesFinder::FILTER_NONE
    end

    def filter_by_any_weight?
      params[:weight].to_s.downcase == ::IssuesFinder::FILTER_ANY
    end

    def assignee_ids?
      params[:assignee_ids].present?
    end

    override :by_assignee
    def by_assignee(items)
      if assignees.any? && !not_query?
        assignees.each do |assignee|
          items = items.assigned_to(assignee)
        end

        return items
      end

      super
    end

    override :assignees
    # rubocop: disable CodeReuse/ActiveRecord
    def assignees
      strong_memoize(:assignees) do
        if assignee_ids?
          ::User.where(id: params[:assignee_ids])
        else
          super
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def by_epic?
      params[:epic_id].present?
    end

    def filter_by_no_epic?
      params[:epic_id].to_s.downcase == ::IssuesFinder::FILTER_NONE
    end

    def epics
      if params[:include_subepics]
        ::Gitlab::ObjectHierarchy.new(::Epic.for_ids(params[:epic_id])).base_and_descendants.select(:id)
      else
        params[:epic_id]
      end
    end

    def by_epic(items)
      return items unless by_epic?

      if filter_by_no_epic?
        items.no_epic
      else
        items.in_epics(epics)
      end
    end
  end
end
