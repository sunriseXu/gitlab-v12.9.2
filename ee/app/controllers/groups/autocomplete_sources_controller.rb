# frozen_string_literal: true

class Groups::AutocompleteSourcesController < Groups::ApplicationController
  before_action :load_autocomplete_service, except: [:members]

  def members
    render json: ::Groups::ParticipantsService.new(@group, current_user).execute(target)
  end

  def issues
    render json: issuable_serializer.represent(@autocomplete_service.issues, parent_group: @group)
  end

  def merge_requests
    render json: issuable_serializer.represent(@autocomplete_service.merge_requests, parent_group: @group)
  end

  def labels
    render json: @autocomplete_service.labels_as_hash(target)
  end

  def epics
    render json: @autocomplete_service.epics
  end

  def commands
    render json: @autocomplete_service.commands(target)
  end

  def milestones
    render json: @autocomplete_service.milestones
  end

  private

  def load_autocomplete_service
    @autocomplete_service = ::Groups::AutocompleteService.new(@group, current_user)
  end

  def issuable_serializer
    GroupIssuableAutocompleteSerializer.new
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def target
    case params[:type]&.downcase
    when 'epic'
      EpicsFinder.new(current_user, group_id: @group.id).find_by(iid: params[:type_id])
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
