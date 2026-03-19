class Api::V1::MapNodeSerializer
  def initialize(map_node)
    @map_node = map_node
  end

  def as_json(*)
    {
      id: @map_node.id,
      network_map_id: @map_node.network_map_id,
      mappable_type: @map_node.mappable_type,
      mappable_id: @map_node.mappable_id,
      x: @map_node.x,
      y: @map_node.y,
      width: @map_node.width,
      height: @map_node.height,
      label_override: @map_node.label_override,
      color: @map_node.color,
      icon: @map_node.icon,
      visible: @map_node.visible,
      collapsed: @map_node.collapsed,
      metadata: @map_node.metadata,
      created_at: @map_node.created_at,
      updated_at: @map_node.updated_at
    }
  end
end
