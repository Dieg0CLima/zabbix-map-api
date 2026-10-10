class Devices::RemovalImpact
  def initialize(device:)
    @device = device
  end

  def call
    maps = map_rows
    links = zabbix_links_counts
    network_links = NetworkLink.for_device(@device.id).count

    {
      device_id: @device.id,
      has_dependencies: maps.any? || links.values.any?(&:positive?) || network_links.positive?,
      maps: maps,
      zabbix_links: links,
      interfaces: @device.device_interfaces.count,
      network_links: network_links,
      cables_left_without_endpoint: cables_left_without_endpoint
    }
  end

  private

  def nodes
    MapNode.where(mappable: @device)
  end

  def map_rows
    nodes.joins(:network_map)
         .group("network_maps.id", "network_maps.name")
         .order("network_maps.id")
         .count
         .map { |(id, name), node_count| { id: id, name: name, node_count: node_count } }
  end

  def zabbix_links_counts
    {
      device: ZabbixLink.where(linkable: @device).count,
      interfaces: ZabbixLink.where(linkable_type: "DeviceInterface", linkable_id: @device.device_interfaces.select(:id)).count
    }
  end

  def cables_left_without_endpoint
    node_ids = nodes.select(:id)
    NetworkCable.where(source_node_id: node_ids).or(NetworkCable.where(target_node_id: node_ids)).count
  end
end
