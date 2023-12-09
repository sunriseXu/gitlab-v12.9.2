# frozen_string_literal: true
require 'spec_helper'

describe API::NugetPackages do
  include WorkhorseHelpers
  include EE::PackagesManagerApiSpecHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :public) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  describe 'GET /api/v4/projects/:id/packages/nuget' do
    let(:url) { "/projects/#{project.id}/packages/nuget/index.json" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget service index request'   | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget service index request'   | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget service index request'   | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget service index request'   | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget service index request'   | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget service index request'   | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget service index request'   | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget service index request'   | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget service index request'   | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget service index request'   | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'         | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'         | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'         | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'         | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'PUT /api/v4/projects/:id/packages/nuget/authorize' do
    let_it_be(:workhorse_token) { JWT.encode({ 'iss' => 'gitlab-workhorse' }, Gitlab::Workhorse.secret, 'HS256') }
    let_it_be(:workhorse_header) { { 'GitLab-Workhorse' => '1.0', Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER => workhorse_token } }
    let(:url) { "/projects/#{project.id}/packages/nuget/authorize" }
    let(:headers) { {} }

    subject { put api(url), headers: headers }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget workhorse authorization' | :success
          'PUBLIC'  | :guest      | true  | true  | 'rejects nuget packages access'         | :forbidden
          'PUBLIC'  | :developer  | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PUBLIC'  | :guest      | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PUBLIC'  | :developer  | false | true  | 'rejects nuget packages access'         | :forbidden
          'PUBLIC'  | :guest      | false | true  | 'rejects nuget packages access'         | :forbidden
          'PUBLIC'  | :developer  | false | false | 'rejects nuget packages access'         | :unauthorized
          'PUBLIC'  | :guest      | false | false | 'rejects nuget packages access'         | :unauthorized
          'PUBLIC'  | :anonymous  | false | true  | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :developer  | true  | true  | 'process nuget workhorse authorization' | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'         | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'         | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'         | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'         | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'         | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:user_headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }
          let(:headers) { user_headers.merge(workhorse_header) }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'PUT /api/v4/projects/:id/packages/nuget' do
    let(:workhorse_token) { JWT.encode({ 'iss' => 'gitlab-workhorse' }, Gitlab::Workhorse.secret, 'HS256') }
    let(:workhorse_header) { { 'GitLab-Workhorse' => '1.0', Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER => workhorse_token } }
    let_it_be(:file_name) { 'package.nupkg' }
    let(:url) { "/projects/#{project.id}/packages/nuget" }
    let(:headers) { {} }
    let(:params) { { package: temp_file(file_name) } }

    subject do
      workhorse_finalize(
        api(url),
        method: :put,
        file_key: :package,
        params: params,
        headers: headers
      )
    end

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget upload'          | :created
          'PUBLIC'  | :guest      | true  | true  | 'rejects nuget packages access' | :forbidden
          'PUBLIC'  | :developer  | true  | false | 'rejects nuget packages access' | :unauthorized
          'PUBLIC'  | :guest      | true  | false | 'rejects nuget packages access' | :unauthorized
          'PUBLIC'  | :developer  | false | true  | 'rejects nuget packages access' | :forbidden
          'PUBLIC'  | :guest      | false | true  | 'rejects nuget packages access' | :forbidden
          'PUBLIC'  | :developer  | false | false | 'rejects nuget packages access' | :unauthorized
          'PUBLIC'  | :guest      | false | false | 'rejects nuget packages access' | :unauthorized
          'PUBLIC'  | :anonymous  | false | true  | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :developer  | true  | true  | 'process nuget upload'          | :created
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access' | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access' | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:user_headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }
          let(:headers) { user_headers.merge(workhorse_header) }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/nuget/metadata/*package_name/index' do
    let_it_be(:package_name) { 'Dummy.Package' }
    let_it_be(:packages) { create_list(:nuget_package, 5, name: package_name, project: project) }
    let(:url) { "/projects/#{project.id}/packages/nuget/metadata/#{package_name}/index.json" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget metadata request at package name level' | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget metadata request at package name level' | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget metadata request at package name level' | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'                        | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'                        | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'                        | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'                        | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'                        | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'                        | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'                        | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'                        | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end

        it_behaves_like 'rejects nuget access with unknown project id'

        it_behaves_like 'rejects nuget access with invalid project id'
      end
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/nuget/metadata/*package_name/*package_version' do
    let_it_be(:package_name) { 'Dummy.Package' }
    let_it_be(:package) { create(:nuget_package, name: 'Dummy.Package', project: project) }
    let(:url) { "/projects/#{project.id}/packages/nuget/metadata/#{package_name}/#{package.version}.json" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget metadata request at package name and package version level' | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget metadata request at package name and package version level' | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget metadata request at package name and package version level' | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'                                            | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'                                            | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'                                            | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'                                            | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'                                            | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'                                            | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'                                            | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'                                            | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      context 'with invalid package name' do
        let_it_be(:package_name) { 'Unkown' }

        it_behaves_like 'rejects nuget packages access', :developer, :not_found
      end
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/nuget/download/*package_name/index' do
    let_it_be(:package_name) { 'Dummy.Package' }
    let_it_be(:packages) { create_list(:nuget_package, 5, name: package_name, project: project) }
    let(:url) { "/projects/#{project.id}/packages/nuget/download/#{package_name}/index.json" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget download versions request'   | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget download versions request'   | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget download versions request'   | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget download versions request'   | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget download versions request'   | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget download versions request'   | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget download versions request'   | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget download versions request'   | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget download versions request'   | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget download versions request'   | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'             | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'             | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'             | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'             | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'             | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'             | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'             | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'             | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/nuget/download/*package_name/*package_version/*package_filename' do
    let_it_be(:package_name) { 'Dummy.Package' }
    let_it_be(:package) { create(:nuget_package, project: project, name: package_name) }

    let(:url) { "/projects/#{project.id}/packages/nuget/download/#{package.name}/#{package.version}/#{package.name}.#{package.version}.nupkg" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget download content request'   | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget download content request'   | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget download content request'   | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget download content request'   | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget download content request'   | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget download content request'   | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget download content request'   | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget download content request'   | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget download content request'   | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget download content request'   | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access'            | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access'            | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access'            | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access'            | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access'            | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access'            | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access'            | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access'            | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/nuget/query' do
    let_it_be(:package_a) { create(:nuget_package, name: 'Dummy.PackageA', project: project) }
    let_it_be(:packages_b) { create_list(:nuget_package, 5, name: 'Dummy.PackageB', project: project) }
    let_it_be(:packages_c) { create_list(:nuget_package, 5, name: 'Dummy.PackageC', project: project) }
    let_it_be(:package_d) { create(:nuget_package, name: 'Dummy.PackageD', version: '5.0.5-alpha', project: project) }
    let_it_be(:package_e) { create(:nuget_package, name: 'Foo.BarE', project: project) }
    let(:search_term) { 'uMmy' }
    let(:take) { 26 }
    let(:skip) { 0 }
    let(:include_prereleases) { true }
    let(:query_parameters) { { q: search_term, take: take, skip: skip, prerelease: include_prereleases } }
    let(:url) { "/projects/#{project.id}/packages/nuget/query?#{query_parameters.to_query}" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process nuget search request'  | :success
          'PUBLIC'  | :guest      | true  | true  | 'process nuget search request'  | :success
          'PUBLIC'  | :developer  | true  | false | 'process nuget search request'  | :success
          'PUBLIC'  | :guest      | true  | false | 'process nuget search request'  | :success
          'PUBLIC'  | :developer  | false | true  | 'process nuget search request'  | :success
          'PUBLIC'  | :guest      | false | true  | 'process nuget search request'  | :success
          'PUBLIC'  | :developer  | false | false | 'process nuget search request'  | :success
          'PUBLIC'  | :guest      | false | false | 'process nuget search request'  | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process nuget search request'  | :success
          'PRIVATE' | :developer  | true  | true  | 'process nuget search request'  | :success
          'PRIVATE' | :guest      | true  | true  | 'rejects nuget packages access' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'rejects nuget packages access' | :not_found
          'PRIVATE' | :guest      | false | true  | 'rejects nuget packages access' | :not_found
          'PRIVATE' | :developer  | false | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'rejects nuget packages access' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'rejects nuget packages access' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects nuget access with unknown project id'

      it_behaves_like 'rejects nuget access with invalid project id'
    end

    it_behaves_like 'rejects nuget packages access with packages features disabled'
  end
end
