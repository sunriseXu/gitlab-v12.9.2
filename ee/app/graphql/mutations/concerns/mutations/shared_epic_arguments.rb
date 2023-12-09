# frozen_string_literal: true

module Mutations
  module SharedEpicArguments
    extend ActiveSupport::Concern

    prepended do
      argument :group_path, GraphQL::ID_TYPE,
               required: true,
               description: "The group the epic to mutate is in"

      argument :title,
                GraphQL::STRING_TYPE,
                required: false,
                description: 'The title of the epic'

      argument :description,
                GraphQL::STRING_TYPE,
                required: false,
                description: 'The description of the epic'

      argument :start_date_fixed,
                GraphQL::STRING_TYPE,
                required: false,
                description: 'The start date of the epic'

      argument :due_date_fixed,
                GraphQL::STRING_TYPE,
                required: false,
                description: 'The end date of the epic'

      argument :start_date_is_fixed,
                GraphQL::BOOLEAN_TYPE,
                required: false,
                description: 'Indicates start date should be sourced from start_date_fixed field not the issue milestones'

      argument :due_date_is_fixed,
                GraphQL::BOOLEAN_TYPE,
                required: false,
                description: 'Indicates end date should be sourced from due_date_fixed field not the issue milestones'
      argument :add_label_ids,
               [GraphQL::ID_TYPE],
               required: false,
               description: 'The IDs of labels to be added to the epic.'
      argument :remove_label_ids,
               [GraphQL::ID_TYPE],
               required: false,
               description: 'The IDs of labels to be removed from the epic.'
    end

    def validate_arguments!(args)
      if args.empty?
        raise Gitlab::Graphql::Errors::ArgumentError,
          'The list of epic attributes is empty'
      end
    end
  end
end
