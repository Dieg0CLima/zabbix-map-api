module CableFusion
  module Validators
    class BrokenLinksValidator
      def initialize(diagram:)
        @diagram = diagram
      end

      def call
        errors = []
        ports_by_id = @diagram.ports.index_by(&:id)

        @diagram.links.each do |link|
          source = ports_by_id[link.source_port_id]
          target = ports_by_id[link.target_port_id]

          errors << error("link_ports_missing", "Link #{link.id} references missing ports", path: "links/#{link.id}") if source.nil? || target.nil?
          errors << error("link_same_port", "Link #{link.id} connects the same port on both sides", path: "links/#{link.id}") if link.source_port_id == link.target_port_id

          if source && target && incompatible_port_direction?(source.port_type, target.port_type)
            errors << error("port_type_incompatible", "Link #{link.id} connects incompatible port directions", path: "links/#{link.id}")
          end
        end

        errors
      end

      private

      def incompatible_port_direction?(source_type, target_type)
        direction(source_type) == direction(target_type) && direction(source_type).in?(%w[in out])
      end

      def direction(port_type)
        return "in" if port_type.to_s.end_with?("_in")
        return "out" if port_type.to_s.end_with?("_out")

        "neutral"
      end

      def error(code, detail, path: nil, meta: {})
        { code:, detail:, path:, meta: }.compact
      end
    end
  end
end
