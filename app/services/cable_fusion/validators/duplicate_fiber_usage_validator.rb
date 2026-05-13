module CableFusion
  module Validators
    class DuplicateFiberUsageValidator
      def initialize(diagram:)
        @diagram = diagram
      end

      def call
        refs = Hash.new(0)
        @diagram.links.each do |link|
          next if link.fiber_side.blank? || link.fiber_number.blank?

          refs[[ link.fiber_side, link.fiber_number ]] += 1
        end

        refs.each_with_object([]) do |((side, number), count), errors|
          next if count <= 1

          errors << error("fiber_ref_conflict", "Fiber #{side}-#{number} is used multiple times", path: "links", meta: { fiber_side: side, fiber_number: number, usage: count })
        end
      end

      private

      def error(code, detail, path: nil, meta: {})
        { code:, detail:, path:, meta: }.compact
      end
    end
  end
end
