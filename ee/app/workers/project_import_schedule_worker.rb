# frozen_string_literal: true

class ProjectImportScheduleWorker # rubocop:disable Scalability/IdempotentWorker
  ImportStateNotFound = Class.new(StandardError)

  include ApplicationWorker
  prepend WaitableWorker

  feature_category :importers
  sidekiq_options retry: false

  def perform(project_id)
    return if Gitlab::Database.read_only?

    project = Project.with_route.with_import_state.with_namespace.find_by_id(project_id)
    raise ImportStateNotFound unless project&.import_state

    with_context(project: project) do
      project.import_state.schedule
    end
  end
end
