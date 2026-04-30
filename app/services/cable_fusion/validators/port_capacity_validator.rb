module CableFusion
  module Validators
    class PortCapacityValidator
      def initialize(diagram:)
        @diagram = diagram
      end

      def call
        usage = Hash.new(0)
        @diagram.links.each do |link|
          usage[link.source_port_id] += 1
          usage[link.target_port_id] += 1
        end

        @diagram.ports.each_with_object([]) do |port, errors|
          next unless usage[port.id] > port.occupancy_limit

          errors << error("port_capacity_exceeded", "Port #{port.id} exceeds occupancy_limit", path: "ports/#{port.id}", meta: { occupancy_limit: port.occupancy_limit, usage: usage[port.id] })
        end
      end

      private

      def error(code, detail, path: nil, meta: {})
        { code:, detail:, path:, meta: }.compact
      end
    end
  end
end
