# frozen_string_literal: true

module Security
  class Scan < ApplicationRecord
    self.table_name = 'security_scans'

    validates :build_id, presence: true
    validates :scan_type, presence: true

    belongs_to :build, class_name: 'Ci::Build'
    has_one :pipeline, class_name: 'Ci::Pipeline', through: :build

    enum scan_type: {
      sast: 1,
      dependency_scanning: 2,
      container_scanning: 3,
      dast: 4
    }
  end
end
