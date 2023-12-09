# frozen_string_literal: true

module HealthStatus
  extend ActiveSupport::Concern
  extend ::Gitlab::Utils::Override

  included do
    enum health_status: {
      on_track: 1,
      needs_attention: 2,
      at_risk: 3
    }
  end

  override :supports_health_status?
  def supports_health_status?
    resource_parent.feature_available?(:issuable_health_status) &&
      ::Feature.enabled?(:save_issuable_health_status, resource_parent)
  end
end
