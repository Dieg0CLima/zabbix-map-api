class Api::V1::MapElementSerializer
  def initialize(map_node)
    @map_node = map_node
  end

  def as_json(*)
    {
      id: @map_node.id,
      network_map_id: @map_node.network_map_id,
      mappable_type: @map_node.mappable_type,
      mappable_id: @map_node.mappable_id,
      kind: @map_node.mappable_type == "Site" ? "site_marker" : "device_marker",
      label: @map_node.label_override.presence || @map_node.mappable&.try(:name) || @map_node.label,
      label_override: @map_node.label_override,
      x: @map_node.x,
      y: @map_node.y,
      lat: @map_node.lat,
      lng: @map_node.lng,
      width: @map_node.width,
      height: @map_node.height,
      color_override: @map_node.color,
      icon_override: @map_node.icon,
      visible: @map_node.visible,
      locked: @map_node.metadata["locked"] || false,
      metadata: @map_node.metadata,
      mappable: serialized_mappable
    }
  end

  private

  def serialized_mappable
    case @map_node.mappable
    when Site then Api::V1::SiteSerializer.new(@map_node.mappable).as_json
    when Device then Api::V1::DeviceSerializer.new(@map_node.mappable).as_json
    end
  end
end
