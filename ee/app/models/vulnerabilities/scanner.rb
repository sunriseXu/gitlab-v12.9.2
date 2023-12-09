# frozen_string_literal: true

module Vulnerabilities
  class Scanner < ApplicationRecord
    self.table_name = "vulnerability_scanners"

    has_many :occurrences, class_name: 'Vulnerabilities::Occurrence'

    belongs_to :project

    validates :project, presence: true
    validates :external_id, presence: true, uniqueness: { scope: :project_id }
    validates :name, presence: true

    scope :with_external_id, -> (external_ids) { where(external_id: external_ids) }
  end
end
