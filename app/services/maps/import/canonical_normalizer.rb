require "set"

module Maps
  module Import
    class CanonicalNormalizer
      DEFAULT_NODE_KIND = "generic".freeze
      DEFAULT_CABLE_TYPE = "manual".freeze
      DEFAULT_CABLE_STATUS = "planned".freeze

      def self.call(payload:)
        new(payload: payload).call
      end

      def initialize(payload:)
        @payload = payload
      end

      def call
        validated = Maps::Import::Contracts::ImportContractV1.validate!(@payload)

        normalized = {
          "schema_version" => validated["schema_version"].to_s,
          "provider" => validated["provider"].to_s.strip.downcase,
          "coordinate_system" => validated["coordinate_system"].to_s.strip.downcase,
          "map" => normalize_map(validated["map"]),
          "nodes" => normalize_nodes(validated["nodes"]),
          "cables" => normalize_cables(validated["cables"])
        }

        validate_uniqueness!(normalized)
        validate_cable_references!(normalized)

        normalized
      end

      private

      def normalize_map(map)
        {
          "name" => map["name"].to_s.strip.presence || map["external_id"].to_s.strip,
          "external_id" => map["external_id"].to_s.strip,
          "metadata" => safe_hash(map["metadata"])
        }
      end

      def normalize_nodes(nodes)
        nodes.map.with_index do |node, index|
          {
            "external_id" => node["external_id"].to_s.strip,
            "label" => node["label"].to_s.strip.presence || node["external_id"].to_s.strip,
            "lat" => to_float(node["lat"], "nodes.#{index}.lat"),
            "lng" => to_float(node["lng"], "nodes.#{index}.lng"),
            "node_kind" => normalize_node_kind(node["node_kind"]),
            "metadata" => safe_hash(node["metadata"])
          }
        end
      end

      def normalize_cables(cables)
        cables.map do |cable|
          {
            "external_id" => cable["external_id"].to_s.strip,
            "label" => cable["label"].to_s.strip.presence || cable["external_id"].to_s.strip,
            "source_external_id" => cable["source_external_id"].to_s.strip,
            "target_external_id" => cable["target_external_id"].to_s.strip,
            "status" => normalize_status(cable["status"]),
            "cable_type" => normalize_cable_type(cable["cable_type"]),
            "metadata" => safe_hash(cable["metadata"]),
            "points" => normalize_points(cable["points"])
          }
        end
      end

      def normalize_points(points)
        Array(points).each_with_index.map do |point, idx|
          {
            "position" => point.is_a?(Hash) ? (point["position"] || point[:position] || idx + 1).to_i : idx + 1,
            "lat" => point.is_a?(Hash) ? point["lat"] || point[:lat] : nil,
            "lng" => point.is_a?(Hash) ? point["lng"] || point[:lng] : nil
          }
        end
      end

      def normalize_node_kind(value)
        candidate = value.to_s.strip.downcase
        return DEFAULT_NODE_KIND if candidate.blank?
        return candidate if MapNode::NODE_KINDS.include?(candidate)

        DEFAULT_NODE_KIND
      end

      def normalize_cable_type(value)
        candidate = value.to_s.strip.downcase
        return DEFAULT_CABLE_TYPE if candidate.blank?
        return candidate if NetworkCable::CABLE_TYPES.include?(candidate)

        DEFAULT_CABLE_TYPE
      end

      def normalize_status(value)
        candidate = value.to_s.strip.downcase
        return DEFAULT_CABLE_STATUS if candidate.blank?
        return candidate if NetworkCable::STATUSES.include?(candidate)

        DEFAULT_CABLE_STATUS
      end

      def validate_uniqueness!(normalized)
        errors = {}

        duplicated_nodes = duplicated_ids(normalized["nodes"], "external_id")
        if duplicated_nodes.any?
          errors["nodes.external_id"] = [ "must be unique" ]
          errors["nodes.external_id.duplicates"] = duplicated_nodes
        end

        duplicated_cables = duplicated_ids(normalized["cables"], "external_id")
        if duplicated_cables.any?
          errors["cables.external_id"] = [ "must be unique" ]
          errors["cables.external_id.duplicates"] = duplicated_cables
        end

        raise_invalid_payload!(errors) if errors.any?
      end

      def validate_cable_references!(normalized)
        known_node_ids = normalized["nodes"].map { |node| node["external_id"] }.to_set
        errors = {}

        normalized["cables"].each_with_index do |cable, index|
          source_id = cable["source_external_id"]
          target_id = cable["target_external_id"]

          unless known_node_ids.include?(source_id)
            add_error(errors, "cables.#{index}.source_external_id", "does not reference an existing node external_id")
          end

          unless known_node_ids.include?(target_id)
            add_error(errors, "cables.#{index}.target_external_id", "does not reference an existing node external_id")
          end
        end

        raise_invalid_payload!(errors) if errors.any?
      end

      def duplicated_ids(records, key)
        records
          .map { |row| row[key].to_s }
          .group_by(&:itself)
          .select { |_id, values| values.size > 1 }
          .keys
      end

      def to_float(value, field)
        return nil if value.nil?
        return value.to_f if value.is_a?(Numeric)

        candidate = value.to_s.strip
        return nil if candidate.blank?
        return candidate.to_f if candidate.match?(/\A-?\d+(\.\d+)?\z/)

        raise_invalid_payload!({ field => [ "must be numeric" ] })
      end

      def safe_hash(value)
        return value if value.is_a?(Hash)

        {}
      end

      def add_error(errors, key, message)
        errors[key] ||= []
        errors[key] << message
      end

      def raise_invalid_payload!(errors)
        raise Maps::Import::Errors::DomainError.new(
          code: "import_payload_invalid",
          message: "Invalid canonical import payload",
          details: { errors: errors }
        )
      end
    end
  end
end
