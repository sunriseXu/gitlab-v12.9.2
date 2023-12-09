# frozen_string_literal: true

module EE
  module Search
    module ProjectService
      extend ::Gitlab::Utils::Override
      include ::Search::Elasticsearchable

      override :execute
      def execute
        return super unless use_elasticsearch? && default_branch?

        ::Gitlab::Elastic::ProjectSearchResults.new(
          current_user,
          params[:search],
          project,
          repository_ref
        )
      end

      def repository_ref
        params[:repository_ref]
      end

      def default_branch?
        return true if repository_ref.blank?

        project.root_ref?(repository_ref)
      end

      def elasticsearchable_scope
        project
      end
    end
  end
end
