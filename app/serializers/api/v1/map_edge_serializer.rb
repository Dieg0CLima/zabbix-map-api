class Api::V1::MapEdgeSerializer
  def initialize(map_edge)
    @map_edge = map_edge
  end

  def as_json(*)
    {
      id: @map_edge.id,
      network_map_id: @map_edge.network_map_id,
      source_node_id: @map_edge.source_node_id,
      target_node_id: @map_edge.target_node_id,
      edge_type: @map_edge.edge_type,
      label: @map_edge.label,
      color: @map_edge.color,
      metadata: @map_edge.metadata,
      created_at: @map_edge.created_at,
      updated_at: @map_edge.updated_at
    }
  end
end
