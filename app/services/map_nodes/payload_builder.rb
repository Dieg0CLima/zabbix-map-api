class MapNodes::PayloadBuilder
  def initialize(map_node:)
    @map_node = map_node
  end

  def call
    {
      id: @map_node.external_id || @map_node.id,
      network_map_id: @map_node.network_map_id,
      pop_id: @map_node.map_pop&.external_id || @map_node.map_pop_id,
      label: @map_node.label,
      external_id: @map_node.external_id,
      node_kind: @map_node.node_kind,
      x: @map_node.x,
      y: @map_node.y,
      lat: @map_node.lat,
      lng: @map_node.lng,
      icon: @map_node.icon,
      color: @map_node.color,
      size: @map_node.size,
      zabbix_ref: @map_node.zabbix_ref,
      zabbix_host_id: @map_node.zabbix_host_id,
      metadata: @map_node.metadata,
      created_at: @map_node.created_at,
      updated_at: @map_node.updated_at
    }
  end
end
