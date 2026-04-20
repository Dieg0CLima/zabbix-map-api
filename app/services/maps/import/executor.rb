require "set"

module Maps
  module Import
    class Executor
      Result = Struct.new(:network_map, :summary, :report, keyword_init: true)

      def initialize(organization:, normalized_payload:, mode:, network_map: nil)
        @organization = organization
        @normalized_payload = normalized_payload
        @mode = mode.to_s
        @network_map = network_map
      end

      def call
        ensure_mode!

        target_map = resolve_target_map
        map_action = target_map.persisted? ? "updated" : "created"
        preview_summary = build_summary_for(target_map, map_action: map_action)

        return Result.new(
          network_map: target_map,
          summary: preview_summary,
          report: build_report(action: "preview", summary: preview_summary)
        ) if preview_mode?

        ActiveRecord::Base.transaction do
          persist_map!(target_map)
          node_index = upsert_nodes!(target_map)
          upsert_cables!(target_map, node_index)
        end

        target_map.reload

        Result.new(
          network_map: target_map,
          summary: preview_summary,
          report: build_report(action: "apply", summary: preview_summary)
        )
      rescue ActiveRecord::RecordInvalid => e
        raise Maps::Import::Errors::DomainError.new(
          code: "import_apply_failed",
          message: "Import apply failed",
          details: { record: e.record.class.name, errors: e.record.errors.to_hash(true) }
        )
      end

      private

      def ensure_mode!
        return if %w[preview apply].include?(@mode)

        raise Maps::Import::Errors::DomainError.new(
          code: "invalid_import_mode",
          message: "Invalid import mode",
          details: { mode: @mode, supported_modes: %w[preview apply] }
        )
      end

      def preview_mode?
        @mode == "preview"
      end

      def resolve_target_map
        return @network_map if @network_map.present?

        @organization.network_maps.find_or_initialize_by(name: normalized_map_name)
      end

      def normalized_map_name
        @normalized_payload.dig("map", "name")
      end

      def persist_map!(network_map)
        metadata = (network_map.metadata || {}).merge(
          "import" => {
            "provider" => @normalized_payload["provider"],
            "external_id" => @normalized_payload.dig("map", "external_id"),
            "schema_version" => @normalized_payload["schema_version"]
          }
        )

        network_map.assign_attributes(
          name: normalized_map_name,
          source_type: network_map.source_type.presence || "manual",
          active_base_layer: network_map.active_base_layer.presence || "standard",
          metadata: metadata
        )
        network_map.save!
      end

      def upsert_nodes!(network_map)
        existing = network_map.map_nodes.index_by(&:external_id)
        node_index = {}

        @normalized_payload.fetch("nodes").each do |node_data|
          node = existing[node_data["external_id"]] || network_map.map_nodes.new(external_id: node_data["external_id"])
          node.assign_attributes(
            label: node_data["label"],
            node_kind: node_data["node_kind"],
            lat: node_data["lat"],
            lng: node_data["lng"],
            x: node_data["lat"],
            y: node_data["lng"],
            metadata: node_data["metadata"]
          )
          node.save!
          node_index[node.external_id] = node
        end

        node_index
      end

      def upsert_cables!(network_map, node_index)
        existing = network_map.network_cables.includes(:network_cable_points).index_by(&:external_id)

        @normalized_payload.fetch("cables").each do |cable_data|
          cable = existing[cable_data["external_id"]] || network_map.network_cables.new(external_id: cable_data["external_id"])
          cable.assign_attributes(
            label: cable_data["label"],
            source_node: node_index.fetch(cable_data["source_external_id"]),
            target_node: node_index.fetch(cable_data["target_external_id"]),
            status: cable_data["status"],
            cable_type: cable_data["cable_type"],
            metadata: cable_data["metadata"]
          )
          cable.save!

          replace_cable_points!(cable, cable_data["points"])
        end
      end

      def replace_cable_points!(cable, points_data)
        cable.network_cable_points.destroy_all

        Array(points_data).each_with_index do |point, idx|
          lat = point["lat"]
          lng = point["lng"]
          position = point["position"] || idx + 1

          cable.network_cable_points.create!(
            position: position.to_i,
            x: lat,
            y: lng
          )
        end
      end

      def build_summary_for(network_map, map_action:)
        existing_nodes = network_map.persisted? ? network_map.map_nodes.pluck(:external_id).to_set : Set.new
        existing_cables = network_map.persisted? ? network_map.network_cables.pluck(:external_id).to_set : Set.new

        payload_nodes = @normalized_payload.fetch("nodes").map { |n| n["external_id"] }
        payload_cables = @normalized_payload.fetch("cables").map { |c| c["external_id"] }

        {
          map: map_action,
          nodes: {
            created: payload_nodes.count { |id| !existing_nodes.include?(id) },
            updated: payload_nodes.count { |id| existing_nodes.include?(id) }
          },
          cables: {
            created: payload_cables.count { |id| !existing_cables.include?(id) },
            updated: payload_cables.count { |id| existing_cables.include?(id) }
          }
        }
      end

      def build_report(action:, summary:)
        {
          action: action,
          provider: @normalized_payload["provider"],
          schema_version: @normalized_payload["schema_version"],
          network_map_name: normalized_map_name,
          summary: summary
        }
      end
    end
  end
end
