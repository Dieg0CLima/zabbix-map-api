module NetworkMaps
  class PayloadBuilder
    def initialize(network_map:)
      @network_map = network_map
    end

    def call
      {
        id:                   @network_map.id,
        organization_id:      @network_map.organization_id,
        name:                 @network_map.name,
        description:          @network_map.description,
        source_type:          @network_map.source_type,
        zabbix_mapid:         @network_map.zabbix_mapid,
        zabbix_connection_id: @network_map.zabbix_connection_id,
        active_base_layer:    @network_map.active_base_layer,
        elements:             elements_payload,
        cables:               cables_payload
      }
    end

    private

    def elements_payload
      @network_map
        .map_elements
        .includes(:mappable)
        .order(:display_order, :id)
        .map { |el| MapElements::PayloadBuilder.new(map_element: el).call }
    end

    def cables_payload
      @network_map.network_cables.includes(:network_cable_points).order(:id).map do |cable|
        {
          id:                cable.external_id || cable.id,
          source_element_id: cable.source_element&.external_id || cable.source_element_id,
          target_element_id: cable.target_element&.external_id || cable.target_element_id,
          label:             cable.label,
          cable_type:        cable.cable_type,
          status:            cable.status,
          bandwidth_mbps:    cable.bandwidth_mbps,
          length_meters:     cable.length_meters,
          color:             cable.color,
          weight:            cable.weight,
          pattern:           cable.pattern,
          metadata:          cable.metadata,
          points:            cable.network_cable_points.order(:position).map do |point|
            {
              id:       point.id,
              position: point.position,
              x:        point.x,
              y:        point.y
            }
          end
        }
      end
    end
  end
end
