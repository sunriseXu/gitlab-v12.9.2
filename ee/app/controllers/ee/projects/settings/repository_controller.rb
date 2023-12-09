# frozen_string_literal: true

module EE
  module Projects
    module Settings
      module RepositoryController
        extend ActiveSupport::Concern

        prepended do
          include SafeMirrorParams

          before_action :push_rule, only: [:show]
        end

        private

        def push_rule
          return unless project.feature_available?(:push_rules)

          project.create_push_rule unless project.push_rule
          @push_rule = project.push_rule # rubocop:disable Gitlab/ModuleWithInstanceVariables
        end

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        def acces_levels_options
          super.merge(
            selected_merge_access_levels: @protected_branch.merge_access_levels.map { |access_level| access_level.user_id || access_level.access_level },
            selected_push_access_levels: @protected_branch.push_access_levels.map { |access_level| access_level.user_id || access_level.access_level },
            selected_create_access_levels: @protected_tag.create_access_levels.map { |access_level| access_level.user_id || access_level.access_level }
          )
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        def load_gon_index
          super

          gon.push(current_project_id: project.id) if project
        end

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        def render_show
          @deploy_tokens = @project.deploy_tokens.active

          define_protected_refs
          push_rule
          remote_mirror

          render 'show'
        end
      end
    end
  end
end
