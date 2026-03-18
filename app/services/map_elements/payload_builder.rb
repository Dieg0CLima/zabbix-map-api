module MapElements
  # Builds the canonical JSON payload for a MapElement, combining:
  #   - domain entity data (name, type-specific fields)
  #   - visual context for this specific map (position, overrides, metadata)
  class PayloadBuilder
    def initialize(map_element:)
      @element = map_element
    end

    def call
      {
        id:             @element.external_id,
        db_id:          @element.id,
        network_map_id: @element.network_map_id,
        mappable_type:  @element.mappable_type,
        mappable_id:    @element.mappable_id,
        external_id:    @element.external_id,

        # Resolved display values (override → entity default)
        label:          @element.display_label,

        # Visual overrides stored in the element itself
        icon_override:  @element.icon_override,
        color_override: @element.color_override,
        label_override: @element.label_override,
        size_override:  @element.size_override,

        # Layout
        lat:            @element.lat,
        lng:            @element.lng,
        collapsed:      @element.collapsed,
        display_order:  @element.display_order,
        metadata:       @element.metadata,

        # Embedded entity data (denormalized for editor performance)
        entity:         entity_payload,

        created_at: @element.created_at,
        updated_at: @element.updated_at
      }
    end

    private

    def entity_payload
      mappable = @element.mappable
      return nil unless mappable

      case @element.mappable_type
      when "Site"
        build_site_payload(mappable)
      when "Device"
        build_device_payload(mappable)
      end
    end

    def build_site_payload(site)
      {
        id:          site.id,
        external_id: site.external_id,
        name:        site.name,
        address:     site.address,
        lat:         site.lat,
        lng:         site.lng,
        status:      site.status,
        metadata:    site.metadata
      }
    end

    def build_device_payload(device)
      {
        id:             device.id,
        external_id:    device.external_id,
        name:           device.name,
        device_type:    device.device_type,
        site_id:        device.site_id,
        zabbix_ref:     device.zabbix_ref,
        zabbix_host_id: device.zabbix_host_id,
        status:         device.status,
        metadata:       device.metadata
      }
    end
  end
end
