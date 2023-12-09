# frozen_string_literal: true

require 'base64'

module API
  class Geo < Grape::API
    resource :geo do
      helpers do
        def sanitized_node_status_params
          allowed_attributes = GeoNodeStatus.attribute_names - ['id']
          valid_attributes = params.keys & allowed_attributes
          params.slice(*valid_attributes)
        end
      end

      # Verify the GitLab Geo transfer request is valid
      # All transfers use the Authorization header to pass a JWT
      # payload.
      #
      # For LFS objects, validate the object ID exists in the DB
      # and that the object ID matches the requested ID. This is
      # a sanity check against some malicious client requesting
      # a random file path.
      params do
        requires :type, type: String, desc: 'File transfer type (e.g. lfs)'
        requires :id, type: Integer, desc: 'The DB ID of the file'
      end
      get 'transfers/:type/:id' do
        check_gitlab_geo_request_ip!

        service = ::Geo::FileUploadService.new(params, headers['Authorization'])
        response = service.execute

        unauthorized! unless response.present?

        if response[:code] == :ok
          file = response[:file]
          present_carrierwave_file!(file)
        else
          error! response, response.delete(:code)
        end
      end

      # Post current node information to primary (e.g. health, repos synced, repos failed, etc.)
      #
      # Example request:
      #   POST /geo/status
      post 'status' do
        check_gitlab_geo_request_ip!
        authenticate_by_gitlab_geo_node_token!

        db_status = GeoNode.find(params[:geo_node_id]).find_or_build_status

        unless db_status.update(sanitized_node_status_params.merge(last_successful_status_check_at: Time.now.utc))
          render_validation_error!(db_status)
        end
      end

      # git push over SSH secondary -> primary related proxying logic
      #
      resource 'proxy_git_push_ssh' do
        format :json

        # Responsible for making HTTP GET /repo.git/info/refs?service=git-receive-pack
        # request *from* secondary gitlab-shell to primary
        #
        params do
          requires :secret_token, type: String
          requires :data, type: Hash do
            requires :gl_id, type: String
            requires :primary_repo, type: String
          end
        end
        post 'info_refs' do
          authenticate_by_gitlab_shell_token!
          params.delete(:secret_token)

          response = Gitlab::Geo::GitPushSSHProxy.new(params['data']).info_refs
          status(response.code)
          response.body
        end

        # Responsible for making HTTP POST /repo.git/git-receive-pack
        # request *from* secondary gitlab-shell to primary
        #
        params do
          requires :secret_token, type: String
          requires :data, type: Hash do
            requires :gl_id, type: String
            requires :primary_repo, type: String
          end
          requires :output, type: String, desc: 'Output from git-receive-pack'
        end
        post 'push' do
          authenticate_by_gitlab_shell_token!
          params.delete(:secret_token)

          response = Gitlab::Geo::GitPushSSHProxy.new(params['data']).push(params['output'])
          status(response.code)
          response.body
        end
      end
    end
  end
end
