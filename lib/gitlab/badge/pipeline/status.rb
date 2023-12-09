# frozen_string_literal: true

module Gitlab
  module Badge
    module Pipeline
      ##
      # Pipeline status badge
      #
      class Status < Badge::Base
        attr_reader :project, :ref

        def initialize(project, ref)
          @project = project
          @ref = ref

          @sha = @project.commit(@ref).try(:sha)
        end

        def entity
          'pipeline'
        end

        # rubocop: disable CodeReuse/ActiveRecord
        def status
          @project.ci_pipelines
            .where(sha: @sha)
            .latest_status(@ref) || 'unknown'
        end
        # rubocop: enable CodeReuse/ActiveRecord

        def metadata
          @metadata ||= Pipeline::Metadata.new(self)
        end

        def template
          @template ||= Pipeline::Template.new(self)
        end
      end
    end
  end
end
