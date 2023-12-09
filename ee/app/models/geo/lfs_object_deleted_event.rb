# frozen_string_literal: true

module Geo
  class LfsObjectDeletedEvent < ApplicationRecord
    include Geo::Model
    include Geo::Eventable

    belongs_to :lfs_object

    validates :lfs_object, :oid, :file_path, presence: true
  end
end
