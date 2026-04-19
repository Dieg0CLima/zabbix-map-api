class Api::V1::MapElementSerializer
  PING_UP_HIGHLIGHT_COLOR = "#00c853".freeze

  def initialize(map_node, site_ping_visual: nil)
    @map_node = map_node
    @site_ping_visual = site_ping_visual || {}
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
      color_override: resolved_color_override,
      icon_override: @map_node.icon,
      visible: @map_node.visible,
      locked: @map_node.metadata["locked"] || false,
      metadata: @map_node.metadata,
      monitoring_ping: @site_ping_visual,
      mappable: serialized_mappable
    }
  end

  private

  def resolved_color_override
    return PING_UP_HIGHLIGHT_COLOR if ping_up?

    @map_node.color
  end

  def ping_up?
    @map_node.mappable_type == "Site" && @site_ping_visual[:status] == "up"
  end

  def serialized_mappable
    case @map_node.mappable
    when Site then Api::V1::SiteSerializer.new(@map_node.mappable).as_json
    when Device then Api::V1::DeviceSerializer.new(@map_node.mappable).as_json
    end
  end
end
