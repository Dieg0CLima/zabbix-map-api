require "digest"

module Maps
  module Import
    module Providers
      class KmzAdapter < BaseAdapter
        SCHEMA_VERSION = "1.0".freeze
        PROVIDER = "kmz".freeze
        DEFAULT_MAP_NAME = "KMZ Import".freeze

        def parse(input:)
          return input if input.is_a?(Hash)

          archive = Maps::Import::Kmz::ArchiveReader.call(input: input)
          parsed = Maps::Import::Kmz::KmlParser.call(kml: archive[:kml])

          parsed.merge(
            source_format: archive[:source_format],
            entry_name: archive[:entry_name],
            raw_kml_sha: Digest::SHA256.hexdigest(archive[:kml].to_s)
          )
        end

        def normalize(parsed:)
          payload = parsed.respond_to?(:deep_stringify_keys) ? parsed.deep_stringify_keys : parsed
          return payload if canonical_contract?(payload)

          placemarks = Array(payload[:placemarks] || payload["placemarks"])
          document = payload[:document] || payload["document"] || {}
          source_format = payload[:source_format] || payload["source_format"]
          entry_name = payload[:entry_name] || payload["entry_name"]
          raw_kml_sha = payload[:raw_kml_sha] || payload["raw_kml_sha"]

          nodes = []
          coordinate_index = {}
          adapter_warnings = []

          point_placemarks = placemarks.select { |item| geometry_type(item) == "point" }
          point_placemarks.each_with_index do |placemark, idx|
            coordinate = point_coordinates(placemark)
            if coordinate.blank?
              adapter_warnings << {
                "kind" => "node_skipped",
                "label" => placemark_name(placemark).presence || "Placemark #{idx + 1}",
                "reason" => "missing_coordinates"
              }
              next
            end

            node = build_point_node(placemark: placemark, index: idx, source_format: source_format, entry_name: entry_name)
            nodes << node
            coordinate_index[coordinate_key(coordinate)] = node
          end

          cables = []
          line_placemarks = placemarks.select { |item| geometry_type(item) == "linestring" }
          line_placemarks.each_with_index do |placemark, idx|
            line_coordinates = linestring_coordinates(placemark)
            if line_coordinates.size < 2
              adapter_warnings << {
                "kind" => "cable_skipped",
                "label" => placemark_name(placemark).presence || "LineString #{idx + 1}",
                "reason" => "insufficient_coordinates",
                "point_count" => line_coordinates.size
              }
              next
            end

            source_node = ensure_endpoint_node!(
              coordinate_index: coordinate_index,
              nodes: nodes,
              coordinate: line_coordinates.first,
              cable_index: idx,
              endpoint: "source",
              source_format: source_format,
              entry_name: entry_name
            )
            target_node = ensure_endpoint_node!(
              coordinate_index: coordinate_index,
              nodes: nodes,
              coordinate: line_coordinates.last,
              cable_index: idx,
              endpoint: "target",
              source_format: source_format,
              entry_name: entry_name
            )

            cables << build_cable(
              placemark: placemark,
              index: idx,
              source_node_id: source_node["external_id"],
              target_node_id: target_node["external_id"],
              line_points: line_coordinates,
              source_format: source_format,
              entry_name: entry_name
            )
          end

          {
            "schema_version" => SCHEMA_VERSION,
            "provider" => PROVIDER,
            "coordinate_system" => "geo",
            "adapter_warnings" => adapter_warnings,
            "map" => {
              "name" => (document[:name] || document["name"]).to_s.strip.presence || DEFAULT_MAP_NAME,
              "external_id" => "kmz-map-#{raw_kml_sha.to_s[0, 16]}",
              "metadata" => {
                "source_format" => source_format,
                "entry_name" => entry_name
              }.compact
            },
            "nodes" => nodes,
            "cables" => cables
          }
        end

        private

        def canonical_contract?(payload)
          return false unless payload.is_a?(Hash)

          required = %w[schema_version provider coordinate_system map nodes cables]
          required.all? { |key| payload.key?(key) }
        end

        def geometry_type(placemark)
          (placemark[:geometry_type] || placemark["geometry_type"]).to_s
        end

        def point_coordinates(placemark)
          coords = placemark[:coordinates] || placemark["coordinates"]
          return nil unless coords.is_a?(Hash)

          { lat: coords[:lat] || coords["lat"], lng: coords[:lng] || coords["lng"] }
        end

        def linestring_coordinates(placemark)
          coords = placemark[:coordinates] || placemark["coordinates"]
          Array(coords).filter_map do |tuple|
            lat = tuple[:lat] || tuple["lat"]
            lng = tuple[:lng] || tuple["lng"]
            next if lat.nil? || lng.nil?

            { lat: lat, lng: lng }
          end
        end

        def build_point_node(placemark:, index:, source_format:, entry_name:)
          coords = point_coordinates(placemark)
          ext = extended_data(placemark)
          name = placemark_name(placemark)
          import_entity = normalize_import_entity(ext["import_entity"] || ext["entity_type"] || ext["kind"])

          external_id = ext["external_id"].presence || deterministic_id("node", index, name, coords)
          site_external_id = ext["site_external_id"].presence || (import_entity.in?(%w[site pop]) ? external_id : nil)
          pop_external_id = ext["pop_external_id"].presence || (import_entity == "pop" ? external_id : nil)

          {
            "external_id" => external_id,
            "label" => name.presence || external_id,
            "lat" => coords[:lat],
            "lng" => coords[:lng],
            "node_kind" => ext["node_kind"],
            "metadata" => {
              "provider_payload" => ext,
              "source_format" => source_format,
              "entry_name" => entry_name,
              "generated_endpoint" => false,
              "import_entity" => import_entity,
              "site_external_id" => site_external_id,
              "site_name" => ext["site_name"].presence || name.presence,
              "pop_external_id" => pop_external_id,
              "pop_name" => ext["pop_name"].presence || name.presence,
              "pop_color" => ext["pop_color"].presence
            }.compact
          }
        end

        def ensure_endpoint_node!(coordinate_index:, nodes:, coordinate:, cable_index:, endpoint:, source_format:, entry_name:)
          key = coordinate_key(coordinate)
          existing = coordinate_index[key]
          return existing if existing

          external_id = deterministic_id("endpoint", cable_index, endpoint, coordinate)
          node = {
            "external_id" => external_id,
            "label" => external_id,
            "lat" => coordinate[:lat],
            "lng" => coordinate[:lng],
            "node_kind" => "generic",
            "metadata" => {
              "source_format" => source_format,
              "entry_name" => entry_name,
              "generated_endpoint" => true,
              "endpoint_role" => endpoint,
              "import_entity" => "generated_endpoint"
            }.compact
          }

          nodes << node
          coordinate_index[key] = node
          node
        end

        def build_cable(placemark:, index:, source_node_id:, target_node_id:, line_points:, source_format:, entry_name:)
          ext = extended_data(placemark)
          name = placemark_name(placemark)
          external_id = ext["external_id"].presence || deterministic_id("cable", index, name, source_node_id, target_node_id)

          {
            "external_id" => external_id,
            "label" => name.presence || external_id,
            "source_external_id" => source_node_id,
            "target_external_id" => target_node_id,
            "status" => ext["status"],
            "cable_type" => ext["cable_type"],
            "metadata" => {
              "provider_payload" => ext,
              "source_format" => source_format,
              "entry_name" => entry_name
            }.compact,
            "points" => line_points.each_with_index.map do |point, idx|
              {
                "position" => idx,
                "lat" => point[:lat],
                "lng" => point[:lng]
              }
            end
          }
        end

        def placemark_name(placemark)
          (placemark[:name] || placemark["name"]).to_s.strip
        end

        def extended_data(placemark)
          ext = placemark[:extended_data] || placemark["extended_data"]
          return {} unless ext.is_a?(Hash)

          ext.each_with_object({}) do |(key, value), acc|
            normalized_key = key.to_s.strip.downcase
            next if normalized_key.blank?

            acc[normalized_key] = value
          end
        end

        def normalize_import_entity(value)
          candidate = value.to_s.strip.downcase
          return "site" if candidate.blank?
          return candidate if %w[site pop node].include?(candidate)

          "site"
        end

        def coordinate_key(point)
          "#{format('%.6f', point[:lat].to_f)}:#{format('%.6f', point[:lng].to_f)}"
        end

        def deterministic_id(prefix, *parts)
          digest = Digest::SHA256.hexdigest(parts.flatten.map(&:to_s).join("|"))[0, 12]
          "#{PROVIDER}-#{prefix}-#{digest}"
        end
      end
    end
  end
end
