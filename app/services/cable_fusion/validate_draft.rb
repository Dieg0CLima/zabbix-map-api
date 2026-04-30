module CableFusion
  class ValidateDraft
    Result = Struct.new(:valid?, :errors, keyword_init: true)

    def initialize(diagram:)
      @diagram = diagram
    end

    def call
      errors = []
      ports_by_id = @diagram.ports.index_by(&:id)
      ports_usage = Hash.new(0)
      fiber_refs = Hash.new(0)

      @diagram.links.each do |link|
        source = ports_by_id[link.source_port_id]
        target = ports_by_id[link.target_port_id]

        errors << error("link_ports_missing", "Link #{link.id} references missing ports") if source.nil? || target.nil?
        errors << error("link_same_port", "Link #{link.id} connects the same port on both sides") if link.source_port_id == link.target_port_id

        if source && target && incompatible_port_direction?(source.port_type, target.port_type)
          errors << error("port_type_incompatible", "Link #{link.id} connects incompatible port directions")
        end

        ports_usage[link.source_port_id] += 1
        ports_usage[link.target_port_id] += 1

        next if link.fiber_side.blank? || link.fiber_number.blank?

        fiber_refs[[link.fiber_side, link.fiber_number]] += 1
      end

      @diagram.ports.each do |port|
        if ports_usage[port.id] > port.occupancy_limit
          errors << error("port_capacity_exceeded", "Port #{port.id} exceeds occupancy_limit")
        end
      end

      fiber_refs.each do |(side, number), count|
        next if count <= 1

        errors << error("fiber_ref_conflict", "Fiber #{side}-#{number} is used multiple times")
      end

      Result.new(valid?: errors.empty?, errors:)
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

    def error(code, detail)
      { code:, detail: }
    end
  end
end
