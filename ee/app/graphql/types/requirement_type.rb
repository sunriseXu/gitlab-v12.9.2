# frozen_string_literal: true

module Types
  class RequirementType < BaseObject
    graphql_name 'Requirement'
    description 'Represents a requirement.'

    authorize :read_requirement

    expose_permissions Types::PermissionTypes::Requirement

    field :id, GraphQL::ID_TYPE, null: false,
          description: 'ID of the requirement'
    field :iid, GraphQL::ID_TYPE, null: false,
          description: 'Internal ID of the requirement'
    field :title, GraphQL::STRING_TYPE, null: true,
          description: 'Title of the requirement'
    field :state, RequirementStateEnum, null: false,
          description: 'State of the requirement'

    field :project, ProjectType, null: false,
          description: 'Project to which the requirement belongs',
          resolve: -> (obj, _args, _ctx) { Gitlab::Graphql::Loaders::BatchModelLoader.new(Project, obj.project_id).find }
    field :author, Types::UserType, null: false,
          description: 'Author of the requirement',
          resolve: -> (obj, _args, _ctx) { Gitlab::Graphql::Loaders::BatchModelLoader.new(User, obj.author_id).find }

    field :created_at, Types::TimeType, null: false,
          description: 'Timestamp of when the requirement was created'
    field :updated_at, Types::TimeType, null: false,
          description: 'Timestamp of when the requirement was last updated'
  end
end
