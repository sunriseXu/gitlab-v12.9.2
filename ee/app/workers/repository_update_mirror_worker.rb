# frozen_string_literal: true

class RepositoryUpdateMirrorWorker # rubocop:disable Scalability/IdempotentWorker
  UpdateError = Class.new(StandardError)

  include ApplicationWorker
  include Gitlab::ShellAdapter
  include ProjectStartImport

  feature_category :source_code_management

  # Retry not necessary. It will try again at the next update interval.
  sidekiq_options retry: false, status_expiration: StuckImportJobsWorker::IMPORT_JOBS_EXPIRATION

  attr_accessor :project, :repository, :current_user

  def perform(project_id)
    project = Project.find(project_id)

    return unless start_mirror(project)

    @current_user = project.mirror_user || project.creator

    result = Projects::UpdateMirrorService.new(project, @current_user).execute
    raise UpdateError, result[:message] if result[:status] == :error

    finish_mirror(project)
  rescue UpdateError => ex
    fail_mirror(project, ex.message)
    raise
  rescue => ex
    return unless project

    fail_mirror(project, ex.message)
    raise UpdateError, "#{ex.class}: #{ex.message}"
  end

  private

  # rubocop:disable Gitlab/RailsLogger
  def start_mirror(project)
    import_state = project.import_state

    if start(import_state)
      Rails.logger.info("Mirror update for #{project.full_path} started. Waiting duration: #{import_state.mirror_waiting_duration}")
      metric_mirror_waiting_duration_seconds.observe({}, import_state.mirror_waiting_duration)

      true
    else
      Rails.logger.info("Project #{project.full_path} was in inconsistent state: #{import_state.status}")
      false
    end
  end
  # rubocop:enable Gitlab/RailsLogger

  def fail_mirror(project, message)
    project.import_state.mark_as_failed(message)

    Rails.logger.error("Mirror update for #{project.full_path} failed with the following message: #{message}") # rubocop:disable Gitlab/RailsLogger
  end

  def finish_mirror(project)
    import_state = project.import_state
    import_state.finish

    Rails.logger.info("Mirror update for #{project.full_path} successfully finished. Update duration: #{import_state.mirror_update_duration}}.") # rubocop:disable Gitlab/RailsLogger
    metric_mirror_update_duration_seconds.observe({}, import_state.mirror_update_duration)
  end

  def metric_mirror_update_duration_seconds
    @metric_mirror_update_duration_seconds ||= Gitlab::Metrics.histogram(
      :gitlab_repository_mirror_update_duration_seconds,
      'Mirror update duration',
      {},
      [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 50.0, 100.0]
    )
  end

  def metric_mirror_waiting_duration_seconds
    @metric_mirror_waiting_duration_seconds ||= Gitlab::Metrics.histogram(
      :gitlab_repository_mirror_waiting_duration_seconds,
      'Waiting length for repository mirror',
      {},
      [0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.500, 2.0, 10.0]
    )
  end
end
