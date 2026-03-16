class NetworkCables::PayloadBuilder
  def initialize(cable:)
    @cable = cable
  end

  def call
    {
      id: @cable.id,
      external_id: @cable.external_id,
      network_map_id: @cable.network_map_id,
      source_site_id: @cable.source_site&.external_id || @cable.source_site_id,
      target_site_id: @cable.target_site&.external_id || @cable.target_site_id,
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
