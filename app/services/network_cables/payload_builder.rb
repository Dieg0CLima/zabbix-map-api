class NetworkCables::PayloadBuilder
  def initialize(cable:)
    @cable = cable
  end

  def call
    {
      id: @cable.id,
      external_id: @cable.external_id,
      network_map_id: @cable.network_map_id,
      network_link_id: @cable.network_link&.external_id || @cable.network_link_id,
      network_link: network_link_payload,
      source_pop_id: @cable.source_pop&.external_id || @cable.source_pop_id,
      target_pop_id: @cable.target_pop&.external_id || @cable.target_pop_id,
      source_node_id: @cable.source_node&.external_id || @cable.source_node_id,
      target_node_id: @cable.target_node&.external_id || @cable.target_node_id,
      label: @cable.label,
      cable_type: @cable.cable_type,
      status: @cable.status,
      color: @cable.color,
      weight: @cable.weight,
      pattern: @cable.pattern,
      bandwidth_mbps: @cable.bandwidth_mbps,
      length_meters: @cable.length_meters,
      metadata: @cable.metadata,
      points: ordered_points
    }
  end

  private

  def network_link_payload
    return if @cable.network_link.blank?

    {
      external_id: @cable.network_link.external_id,
      label: @cable.network_link.label,
      zabbix_item_ref: @cable.network_link.zabbix_item_ref
    }
  end

  def ordered_points
    @cable.network_cable_points.order(:position).map do |point|
      {
        id: point.id,
        position: point.position,
        x: point.x,
        y: point.y,
        lat: point.x,
        lng: point.y
      }
    end
  end
end
