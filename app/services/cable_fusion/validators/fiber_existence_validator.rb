module CableFusion
  module Validators
    class FiberExistenceValidator
      VALID_SIDES = %w[a b internal none].freeze

      def initialize(diagram:)
        @diagram = diagram
      end

      def call
        errors = []
        fiber_count = @diagram.network_cable.metadata.to_h["fiber_count"].to_i

        @diagram.links.each do |link|
          next if link.fiber_side.blank? && link.fiber_number.blank?

          if link.fiber_side.present? && !VALID_SIDES.include?(link.fiber_side)
            errors << error("fiber_side_invalid", "Link #{link.id} has invalid fiber_side #{link.fiber_side}", path: "links/#{link.id}", meta: { fiber_side: link.fiber_side })
          end

          if link.fiber_number.present? && link.fiber_number.to_i <= 0
            errors << error("fiber_number_invalid", "Link #{link.id} has invalid fiber_number", path: "links/#{link.id}", meta: { fiber_number: link.fiber_number })
          end

          if fiber_count.positive? && link.fiber_number.present? && link.fiber_number.to_i > fiber_count
            errors << error("fiber_number_out_of_range", "Link #{link.id} references fiber #{link.fiber_number} outside cable fiber_count #{fiber_count}", path: "links/#{link.id}", meta: { fiber_number: link.fiber_number, fiber_count: fiber_count })
          end
        end

        errors
      end

      private

      def error(code, detail, path: nil, meta: {})
        { code:, detail:, path:, meta: }.compact
      end
    end
  end
end
