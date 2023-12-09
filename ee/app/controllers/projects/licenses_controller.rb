# frozen_string_literal: true

module Projects
  class LicensesController < Projects::ApplicationController
    before_action :authorize_read_licenses!, only: [:index]
    before_action :authorize_admin_software_license_policy!, only: [:create, :update]
    before_action do
      push_frontend_feature_flag(:license_policy_list, default_enabled: true)
    end

    def index
      respond_to do |format|
        format.html do
          @licenses_app_data = licenses_app_data
          render status: :ok
        end
        format.json do
          ::Gitlab::UsageDataCounters::LicensesList.count(:views)

          license_compliance = project.license_compliance
          render json: serializer.represent(
            pageable(matching_policies_from(license_compliance)),
            build: license_compliance.latest_build_for_default_branch
          )
        end
      end
    end

    def create
      result = ::Projects::Licenses::CreatePolicyService
        .new(project, current_user, software_license_policy_params)
        .execute

      if result[:status] == :success
        render json: LicenseEntity.represent(result[:software_license_policy]), status: :created
      else
        render_error_for(result)
      end
    end

    def update
      result = ::Projects::Licenses::UpdatePolicyService
        .new(project, current_user, software_license_policy_params)
        .execute(params[:id])

      if result[:status] == :success
        render json: LicenseEntity.represent(result[:software_license_policy]), status: :ok
      else
        render_error_for(result)
      end
    end

    private

    def serializer
      ::LicensesListSerializer.new(project: project, user: current_user)
          .with_pagination(request, response)
    end

    def pageable(items)
      ::Gitlab::ItemsCollection.new(items)
    end

    def software_license_policy_params
      params.require(:software_license_policy).permit(:software_license_id, :spdx_identifier, :classification)
    end

    def render_error_for(result)
      render json: { errors: result[:message].as_json }, status: result.fetch(:http_status, :unprocessable_entity)
    end

    def matching_policies_params
      params.permit(:detected, classification: [])
    end

    def matching_policies_from(license_compliance)
      filters = matching_policies_params
      license_compliance.find_policies(
        detected_only: truthy?(filters[:detected]),
        classification: filters[:classification]
      )
    end

    def truthy?(value)
      value.in?(%w[true 1])
    end

    def write_license_policies_endpoint
      if can?(current_user, :admin_software_license_policy, @project)
        expose_path(api_v4_projects_managed_licenses_path(id: @project.id))
      else
        ''
      end
    end

    def licenses_app_data
      {
        project_licenses_endpoint: project_licenses_path(@project, detected: true, format: :json),
        read_license_policies_endpoint: expose_path(api_v4_projects_managed_licenses_path(id: @project.id)),
        write_license_policies_endpoint: write_license_policies_endpoint,
        documentation_path: help_page_path('user/application_security/license_compliance/index'),
        empty_state_svg_path: helpers.image_path('illustrations/Dependency-list-empty-state.svg')
      }
    end
  end
end
