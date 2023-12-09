# frozen_string_literal: true

module Geo
  class DesignRegistryFinder < RegistryFinder
    def count_syncable
      GeoNode.find(current_node_id).projects.with_designs.count
    end

    def count_synced
      registries
        .merge(Geo::DesignRegistry.synced).count
    end

    def count_failed
      registries
        .merge(Geo::DesignRegistry.failed).count
    end

    def count_registry
      registries.count
    end

    private

    def registries
      current_node
        .projects
        .with_designs
        .inner_join_design_registry
    end
  end
end
