# frozen_string_literal: true

# Finder for retrieving project registries that have verification failed
# scoped to a type (repository or wiki) using FDW queries.
#
# Basic usage:
#
#     Geo::ProjectRegistryVerificationFailedFinder.new(current_node: Gitlab::Geo.current_node, :repository).execute
#
# Valid `type` values are:
#
# * `:repository`
# * `:wiki`
#
# Any other value will be ignored.
module Geo
  class ProjectRegistryVerificationFailedFinder
    def initialize(current_node:, type:)
      @current_node = Geo::Fdw::GeoNode.find(current_node.id)
      @type = type.to_s.to_sym
    end

    def execute
      current_node.project_registries.verification_failed(type)
    end

    private

    attr_reader :current_node, :type
  end
end
