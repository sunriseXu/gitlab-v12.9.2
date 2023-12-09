# frozen_string_literal: true

module API
  class Vulnerabilities < Grape::API
    include ::API::Helpers::VulnerabilitiesHooks
    include PaginationParams

    helpers ::API::Helpers::VulnerabilitiesHelpers

    helpers do
      def vulnerabilities_by(project)
        Security::VulnerabilitiesFinder.new(project).execute
      end

      def find_vulnerability!
        Vulnerability.with_findings.find(params[:id])
      end

      def render_vulnerability(vulnerability)
        if vulnerability.valid?
          present vulnerability, with: EE::API::Entities::Vulnerability
        else
          render_validation_error!(vulnerability)
        end
      end
    end

    params do
      requires :id, type: String, desc: 'The ID of a vulnerability'
    end
    resource :vulnerabilities do
      desc 'Get a vulnerability' do
        success EE::API::Entities::Vulnerability
      end
      get ':id' do
        vulnerability = Vulnerability.find(params[:id])
        authorize_vulnerability!(vulnerability, :read_vulnerability)
        render_vulnerability(vulnerability)
      end

      desc 'Resolve a vulnerability' do
        success EE::API::Entities::Vulnerability
      end
      post ':id/resolve' do
        vulnerability = find_and_authorize_vulnerability!(:admin_vulnerability)
        break not_modified! if vulnerability.resolved?

        vulnerability = ::Vulnerabilities::ResolveService.new(current_user, vulnerability).execute
        render_vulnerability(vulnerability)
      end

      desc 'Dismiss a vulnerability' do
        success EE::API::Entities::Vulnerability
      end
      post ':id/dismiss' do
        vulnerability = find_and_authorize_vulnerability!(:admin_vulnerability)
        break not_modified! if vulnerability.dismissed?

        vulnerability = ::Vulnerabilities::DismissService.new(current_user, vulnerability).execute
        render_vulnerability(vulnerability)
      end

      desc 'Confirm a vulnerability' do
        success EE::API::Entities::Vulnerability
      end
      post ':id/confirm' do
        vulnerability = find_and_authorize_vulnerability!(:admin_vulnerability)
        break not_modified! if vulnerability.confirmed?

        vulnerability = ::Vulnerabilities::ConfirmService.new(current_user, vulnerability).execute
        render_vulnerability(vulnerability)
      end
    end

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of project vulnerabilities' do
        success EE::API::Entities::Vulnerability
      end
      params do
        use :pagination
      end
      get ':id/vulnerabilities' do
        authorize! :read_vulnerability, user_project

        vulnerabilities = paginate(
          vulnerabilities_by(user_project)
        )

        present vulnerabilities, with: EE::API::Entities::Vulnerability
      end

      desc 'Create a new Vulnerability (from a confirmed Finding)' do
        success EE::API::Entities::Vulnerability
      end
      params do
        requires :finding_id, type: Integer, desc: 'The id of confirmed vulnerability finding'
      end
      post ':id/vulnerabilities' do
        authorize! :create_vulnerability, user_project

        vulnerability = ::Vulnerabilities::CreateService.new(
          user_project, current_user, finding_id: params[:finding_id]
        ).execute

        if vulnerability.persisted?
          present vulnerability, with: EE::API::Entities::Vulnerability
        else
          render_validation_error!(vulnerability)
        end
      end
    end
  end
end
