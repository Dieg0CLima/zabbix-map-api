module CableFusion
  module Validators
    class PublishReadinessValidator
      def initialize(diagram:)
        @diagram = diagram
      end

      def call
        errors = []
        errors << error("publish_diagram_empty", "Diagram has no nodes", path: "nodes") if @diagram.nodes.empty?
        errors << error("publish_ports_empty", "Diagram has no ports", path: "ports") if @diagram.ports.empty?
        errors << error("publish_links_empty", "Diagram has no links", path: "links") if @diagram.links.empty?
        errors << error("publish_archived", "Archived diagram cannot be published", path: "status") if @diagram.status == "archived"
        errors
      end

      private

      def error(code, detail, path: nil, meta: {})
        { code:, detail:, path:, meta: }.compact
      end
    end
  end
end
