# frozen_string_literal: true

module EE
  module Gitlab
    module Checks
      module PushRules
        class FileSizeCheck < ::Gitlab::Checks::BaseChecker
          LOG_MESSAGE = "Checking if any files are larger than the allowed size...".freeze

          def validate!
            return if push_rule.nil? || push_rule.max_file_size.zero?

            logger.log_timed(LOG_MESSAGE) do
              max_file_size = push_rule.max_file_size
              blobs = project.repository.new_blobs(newrev, dynamic_timeout: logger.time_left)

              large_blob = blobs.find do |blob|
                ::Gitlab::Utils.bytes_to_megabytes(blob.size) > max_file_size
              end

              if large_blob
                raise ::Gitlab::GitAccess::ForbiddenError, %Q{File "#{large_blob.path}" is larger than the allowed size of #{max_file_size} MB}
              end
            end
          end
        end
      end
    end
  end
end
