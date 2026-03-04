module NetworkMaps
  class PayloadBuilder
    def initialize(network_map:)
      @network_map = network_map
    end

    def call
      {
        id: @network_map.id,
        organization_id: @network_map.organization_id,
        name: @network_map.name,
        description: @network_map.description,
        source_type: @network_map.source_type,
        zabbix_mapid: @network_map.zabbix_mapid,
        zabbix_connection_id: @network_map.zabbix_connection_id,
        active_base_layer: @network_map.active_base_layer,
        pops: pops_payload,
        nodes: nodes_payload,
        cables: cables_payload
      }
    end

    private

    def pops_payload
      @network_map.map_pops.order(:id).map do |pop|
        {
          id: pop.external_id || pop.id,
          name: pop.name,
          lat: pop.lat,
          lng: pop.lng,
          color: pop.color,
          metadata: pop.metadata
        }
      end
    end

    def nodes_payload
      @network_map.map_nodes.order(:id).map do |node|
        {
          id: node.external_id || node.id,
          pop_id: node.map_pop&.external_id || node.map_pop_id,
          label: node.label,
          node_kind: node.node_kind,
          x: node.x,
          y: node.y,
          lat: node.lat,
          lng: node.lng,
          icon: node.icon,
          color: node.color,
          size: node.size,
          zabbix_ref: node.zabbix_ref,
          metadata: node.metadata
        }
      end
    end

    def cables_payload
      @network_map.network_cables.order(:id).map do |cable|
        {
          id: cable.external_id || cable.id,
          source_pop_id: cable.source_pop&.external_id || cable.source_pop_id,
          target_pop_id: cable.target_pop&.external_id || cable.target_pop_id,
          source_node_id: cable.source_node&.external_id || cable.source_node_id,
          target_node_id: cable.target_node&.external_id || cable.target_node_id,
          label: cable.label,
          cable_type: cable.cable_type,
          status: cable.status,
          bandwidth_mbps: cable.bandwidth_mbps,
          length_meters: cable.length_meters,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          metadata: cable.metadata,
          points: cable.network_cable_points.order(:position).map do |point|
            {
              id: point.id,
              position: point.position,
              x: point.x,
              y: point.y
            }
          end
        }
      end
    end
  end
end
