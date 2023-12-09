# frozen_string_literal: true

module StatusPage
  module Storage
    # Size limit of the generated JSON uploaded to CDN.
    JSON_MAX_SIZE = 1.megabyte
    # Limit the amount of the recent incidents in the JSON list
    MAX_RECENT_INCIDENTS = 20
    # Limit the amount of comments per incident
    MAX_COMMENTS = 100

    def self.details_path(id)
      "data/incident/#{id}.json"
    end

    def self.list_path
      'data/list.json'
    end

    class Error < StandardError
      def initialize(bucket:, error:, **args)
        super(
          "Error occured #{error.class.name.inspect} " \
          "for bucket #{bucket.inspect}. " \
          "Arguments: #{args.inspect}"
        )
      end
    end
  end
end
