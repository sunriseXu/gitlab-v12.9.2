# frozen_string_literal: true
module MergeTrains
  class CreatePipelineService < BaseService
    def execute(merge_request, previous_ref)
      validation_status = validate(merge_request)
      return validation_status unless validation_status[:status] == :success

      merge_status = create_train_ref(merge_request, previous_ref)
      return error(merge_status[:message]) unless merge_status[:status] == :success

      create_pipeline(merge_request, merge_status)
    end

    private

    def validate(merge_request)
      return error('merge trains is disabled') unless merge_request.project.merge_trains_enabled?
      return error('merge request is not on a merge train') unless merge_request.on_train?
      return error('fork merge request is not supported') if merge_request.for_fork?

      success
    end

    def create_train_ref(merge_request, previous_ref)
      return error('previous ref is not specified') unless previous_ref

      commit_message = commit_message(merge_request, previous_ref)

      ::MergeRequests::MergeToRefService.new(merge_request.project, merge_request.merge_user,
                                             target_ref: merge_request.train_ref_path,
                                             first_parent_ref: previous_ref,
                                             commit_message: commit_message)
                                        .execute(merge_request)
    end

    def commit_message(merge_request, previous_ref)
      "Merge branch #{merge_request.source_branch} with #{previous_ref} " \
      "into #{merge_request.train_ref_path}"
    end

    def create_pipeline(merge_request, merge_status)
      pipeline = ::Ci::CreatePipelineService.new(merge_request.source_project, merge_request.merge_user,
        ref: merge_request.train_ref_path,
        checkout_sha: merge_status[:commit_id],
        target_sha: merge_status[:target_id],
        source_sha: merge_status[:source_id])
        .execute(:merge_request_event, merge_request: merge_request)

      return error(pipeline.error_messages) unless pipeline.persisted?

      success(pipeline: pipeline)
    end
  end
end
