# frozen_string_literal: true

module StatusPage
  # Render a list of issues as incidents and publish them to CDN.
  #
  # This is an internal service which is part of
  # +StatusPage::PublishIncidentService+ and is not meant to be called directly.
  #
  # Consider calling +StatusPage::PublishIncidentService+ instead.
  class PublishListService < PublishBaseService
    private

    def publish(issues)
      json = serialize(issues)

      upload(object_key, json)
    end

    def serialize(issues)
      serializer.represent_list(issues)
    end

    def object_key
      StatusPage::Storage.list_path
    end
  end
end
