class Api::V1::NetworkMapSerializer
  def initialize(network_map)
    @network_map = network_map
  end

  def as_json(*)
    {
      id: @network_map.id,
      organization_id: @network_map.organization_id,
      name: @network_map.name,
      description: @network_map.description,
      metadata: @network_map.metadata,
      source_type: @network_map.source_type,
      active_base_layer: @network_map.active_base_layer,
      zabbix_connection_id: @network_map.zabbix_connection_id,
      created_at: @network_map.created_at,
      updated_at: @network_map.updated_at
    }
  end
end
