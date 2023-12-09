# frozen_string_literal: true

# This class represents an Epic's aggregate information (added up counts) about its child epics and direct issues

module Gitlab
  module Graphql
    module Aggregations
      module Epics
        class EpicNode
          include ::Gitlab::Graphql::Aggregations::Epics::Constants
          include Gitlab::Utils::StrongMemoize

          attr_reader :epic_id, :epic_state_id, :epic_info_flat_list, :parent_id,
                      :count_aggregate, :weight_sum_aggregate

          attr_accessor :children, :calculated_count_totals, :calculated_weight_sum_totals

          def initialize(epic_id, flat_info_list)
            # epic aggregate records from the DB loader look like the following:
            # { 1 => [{iid: 1, parent_id: nil, epic_state_id: 1, issues_count: 1, issues_weight_sum: 2, issues_state_id: 2}] ... }
            # They include the sum of each epic's direct issues, grouped by status,
            # so in order to get a sum of the entire tree, we have to add that up recursively
            @epic_id = epic_id
            @epic_info_flat_list = flat_info_list
            @children = []
            @sums = {}

            set_epic_attributes(flat_info_list.first) # there will always be one
          end

          def aggregate_count
            strong_memoize(:count_aggregate) do
              OpenStruct.new({
                opened_issues: sum_objects(COUNT, OPENED_ISSUE_STATE, ISSUE_TYPE),
                closed_issues: sum_objects(COUNT, CLOSED_ISSUE_STATE, ISSUE_TYPE),
                opened_epics: sum_objects(COUNT, OPENED_EPIC_STATE, EPIC_TYPE),
                closed_epics: sum_objects(COUNT, CLOSED_EPIC_STATE, EPIC_TYPE)
             })
            end
          end

          def aggregate_weight_sum
            strong_memoize(:weight_sum_aggregate) do
              OpenStruct.new({
                opened_issues: sum_objects(WEIGHT_SUM, OPENED_ISSUE_STATE, ISSUE_TYPE),
                closed_issues: sum_objects(WEIGHT_SUM, CLOSED_ISSUE_STATE, ISSUE_TYPE)
               })
            end
          end

          def to_s
            {
                epic_id: @epic_id,
                parent_id: @parent_id,
                children: children,
                object_id: object_id
            }.to_s
          end

          def sum_objects(facet, state, type)
            key = [facet, state, type]
            return @sums[key] if @sums[key]

            direct_sum = value_from_records(*key)
            sum_from_children = children.inject(0) do |total, child|
              total += child.sum_objects(*key)
              total
            end

            @sums[key] = direct_sum + sum_from_children
          end

          private

          def set_epic_attributes(record)
            @epic_state_id = record[:epic_state_id]
            @parent_id = record[:parent_id]
          end

          def value_from_records(facet, state, type)
            # DB records look like:
            # {iid: 1, epic_state_id: 1, issues_count: 1, issues_weight_sum: 2, parent_id: nil, issues_state_id: 2}
            if type == EPIC_TYPE
              # can only be COUNT
              children.select { |node| node.epic_state_id == state }.count
            else
              matching_record = epic_info_flat_list.find do |record|
                record[:issues_state_id] == state
              end || {}

              matching_record.fetch("issues_#{facet}".to_sym, 0)
            end
          end
        end
      end
    end
  end
end
