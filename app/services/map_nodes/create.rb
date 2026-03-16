class MapNodes::Create
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    map_node = @network_map.map_nodes.new(linked_payload)
    map_node.save!
    auto_create_device!(map_node) if should_create_device?(map_node)
    map_node
  end

  private

  def linked_payload
    @linked_payload ||= MapNodes::ZabbixHostLinker.new(network_map: @network_map, payload: @payload).call
  end

  def should_create_device?(node)
    Device::EQUIPMENT_KINDS.include?(node.node_kind) && node.device_id.blank?
  end

  # Auto-creates a Device inventory record linked to this map node.
  # Inherits site from the POP (if the node belongs to a POP with a Site).
  def auto_create_device!(node)
    device = @network_map.organization.devices.create!(
      name: node.label,
      device_type: node.node_kind,
      site_id: node.map_pop&.site_id,
      zabbix_ref: node.zabbix_ref
    )
    node.update_column(:device_id, device.id)
  end
end
