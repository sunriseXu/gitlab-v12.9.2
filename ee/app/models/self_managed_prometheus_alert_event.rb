# frozen_string_literal: true

class SelfManagedPrometheusAlertEvent < ApplicationRecord
  include AlertEventLifecycle

  belongs_to :project, validate: true, inverse_of: :self_managed_prometheus_alert_events
  belongs_to :environment, validate: true, inverse_of: :self_managed_prometheus_alert_events
  has_and_belongs_to_many :related_issues, class_name: 'Issue', join_table: :issues_self_managed_prometheus_alert_events

  validates :started_at, presence: true
  validates :payload_key, uniqueness: { scope: :project_id }

  def self.find_or_initialize_by_payload_key(project, payload_key)
    find_or_initialize_by(project: project, payload_key: payload_key) do |event|
      yield event if block_given?
    end
  end

  def self.payload_key_for(started_at, alert_name, query_expression)
    plain = [started_at, alert_name, query_expression].join('/')

    Digest::SHA1.hexdigest(plain)
  end
end
