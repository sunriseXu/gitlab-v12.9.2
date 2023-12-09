# frozen_string_literal: true

module Types
  module EpicTree
    # rubocop: disable Graphql/AuthorizeTypes
    class EpicTreeNodeInputType < BaseInputObject
      graphql_name 'EpicTreeNodeFieldsInputType'
      description 'A node of an epic tree.'

      argument :id,
               GraphQL::ID_TYPE,
               required: true,
               description: 'The id of the epic_issue or epic that is being moved'

      argument :adjacent_reference_id,
               GraphQL::ID_TYPE,
               required: true,
               description: 'The id of the epic_issue or issue that the actual epic or issue is switched with'

      argument :relative_position,
               MoveTypeEnum,
               required: true,
               description: 'The type of the switch, after or before allowed'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
