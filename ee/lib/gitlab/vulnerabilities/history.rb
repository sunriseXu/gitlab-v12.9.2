# frozen_string_literal: true

require 'vulnerabilities/history_serializer'

module Gitlab
  module Vulnerabilities
    class History
      attr_reader :vulnerable, :filters

      HISTORY_RANGE = 3.months
      NoProjectIDsError = Class.new(StandardError)

      def initialize(vulnerable, params:)
        @vulnerable = vulnerable
        @filters = params
      end

      def findings_counter
        return cached_vulnerability_history unless dynamic_filters_included?

        findings = vulnerability_findings.count_by_day_and_severity(HISTORY_RANGE)
        ::Vulnerabilities::HistorySerializer.new.represent(findings)
      end

      private

      def vulnerability_findings
        ::Security::VulnerabilityFindingsFinder.new(pipeline_ids, params: filters).execute
      end

      def cached_vulnerability_history
        history = { info: {}, unknown: {}, low: {}, medium: {}, high: {}, critical: {}, total: {} }

        project_ids_to_fetch.each do |project_id|
          project_history = Gitlab::Vulnerabilities::HistoryCache.new(vulnerable, project_id).fetch(HISTORY_RANGE)
          history.each do |key, value|
            value.merge!(project_history[key]) { |k, aggregate, project_count| aggregate + project_count }
          end
        end

        sort_by_date_for_each_key(history)
      end

      def sort_by_date_for_each_key(history)
        history.each do |key, value|
          history[key] = value.sort_by { |date, count| date }.to_h
        end

        history
      end

      def dynamic_filters_included?
        dynamic_filters = [:report_type, :confidence, :severity]
        filters.keys.any? { |key| dynamic_filters.include?(key.to_sym) }
      end

      def project_ids_to_fetch
        return filters[:project_id] if filters.key?('project_id')

        vulnerable.project_ids_with_security_reports
      end

      def pipeline_ids
        vulnerable.all_pipelines.with_vulnerabilities.success
      end
    end
  end
end
