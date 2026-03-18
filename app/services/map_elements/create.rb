module MapElements
  # Creates a MapElement that links an existing domain entity (Site or Device)
  # into a NetworkMap with optional visual overrides.
  class Create
    def initialize(network_map:, payload:)
      @network_map = network_map
      @payload = payload
    end

    def call
      element = @network_map.map_elements.new(resolved_payload)
      element.save!
      element
    end

    private

    def resolved_payload
      attrs = @payload.slice(
        :external_id, :lat, :lng,
        :icon_override, :color_override, :label_override, :size_override,
        :collapsed, :display_order, :metadata
      )

      attrs[:mappable_type] = @payload[:mappable_type]
      attrs[:mappable_id]   = resolve_mappable_id

      attrs
    end

    def resolve_mappable_id
      type = @payload[:mappable_type]
      id   = @payload[:mappable_id]

      case type
      when "Site"
        @network_map.organization.sites.find(id).id
      when "Device"
        @network_map.organization.devices.find(id).id
      else
        raise ArgumentError, "Unsupported mappable_type: #{type}"
      end
    end
  end
end
