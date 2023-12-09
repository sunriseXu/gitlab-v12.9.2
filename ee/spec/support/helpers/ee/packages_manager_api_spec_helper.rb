# frozen_string_literal: true

module EE
  module PackagesManagerApiSpecHelpers
    def build_auth_headers(value)
      { 'HTTP_AUTHORIZATION' => value }
    end

    def build_basic_auth_header(username, password)
      build_auth_headers(ActionController::HttpAuthentication::Basic.encode_credentials(username, password))
    end

    def build_token_auth_header(token)
      build_auth_headers("Bearer #{token}")
    end

    def build_jwt(personal_access_token, secret: jwt_secret, user_id: nil)
      JSONWebToken::HMACToken.new(secret).tap do |jwt|
        jwt['access_token'] = personal_access_token.id
        jwt['user_id'] = user_id || personal_access_token.user_id
      end
    end

    def build_jwt_from_job(job, secret: jwt_secret)
      JSONWebToken::HMACToken.new(secret).tap do |jwt|
        jwt['access_token'] = job.token
        jwt['user_id'] = job.user.id
      end
    end

    def temp_file(package_tmp)
      upload_path = ::Packages::PackageFileUploader.workhorse_local_upload_path
      file_path = "#{upload_path}/#{package_tmp}"

      FileUtils.mkdir_p(upload_path)
      File.write(file_path, 'test')

      UploadedFile.new(file_path, filename: File.basename(file_path))
    end
  end
end
