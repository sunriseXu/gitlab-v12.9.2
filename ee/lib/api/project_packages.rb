# frozen_string_literal: true

module API
  class ProjectPackages < Grape::API
    include PaginationParams

    before do
      authorize_packages_access!(user_project)
    end

    helpers ::API::Helpers::PackagesHelpers

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get all project packages' do
        detail 'This feature was introduced in GitLab 11.8'
        success EE::API::Entities::Package
      end
      params do
        use :pagination
        optional :order_by, type: String, values: %w[created_at name version type], default: 'created_at',
                            desc: 'Return packages ordered by `created_at`, `name`, `version` or `type` fields.'
        optional :sort, type: String, values: %w[asc desc], default: 'asc',
                        desc: 'Return packages sorted in `asc` or `desc` order.'
        optional :package_type, type: String, values: %w[conan maven npm nuget],
                                desc: 'Return packages of a certain type'
        optional :package_name, type: String,
                                desc: 'Return packages with this name'
      end
      get ':id/packages' do
        packages = ::Packages::PackagesFinder
          .new(user_project, declared(params)).execute

        present paginate(packages), with: EE::API::Entities::Package, user: current_user
      end

      desc 'Get a single project package' do
        detail 'This feature was introduced in GitLab 11.9'
        success EE::API::Entities::Package
      end
      params do
        requires :package_id, type: Integer, desc: 'The ID of a package'
      end
      get ':id/packages/:package_id' do
        package = ::Packages::PackageFinder
          .new(user_project, params[:package_id]).execute

        present package, with: EE::API::Entities::Package, user: current_user
      end

      desc 'Remove a package' do
        detail 'This feature was introduced in GitLab 11.9'
      end
      params do
        requires :package_id, type: Integer, desc: 'The ID of a package'
      end
      delete ':id/packages/:package_id' do
        authorize_destroy_package!(user_project)

        package = ::Packages::PackageFinder
          .new(user_project, params[:package_id]).execute

        destroy_conditionally!(package)
      end
    end
  end
end
