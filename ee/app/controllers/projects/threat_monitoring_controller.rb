# frozen_string_literal: true

module Projects
  class ThreatMonitoringController < Projects::ApplicationController
    before_action :authorize_read_threat_monitoring!

    before_action only: [:show] do
      push_frontend_feature_flag(:network_policy_ui)
    end
  end
end
