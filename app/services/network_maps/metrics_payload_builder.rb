class NetworkMaps::MetricsPayloadBuilder
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id: @network_map.id,
      collected_at: Time.current,
      nodes: node_metrics
    }
  end

  private

  def node_metrics
    @network_map.map_nodes
                .includes(:zabbix_host, map_node_items: :zabbix_item)
                .order(:id)
                .map { |node| build_node_metrics(node) }
  end

  def build_node_metrics(node)
    {
      id: node.external_id || node.id,
      external_id: node.external_id,
      label: node.label,
      node_kind: node.node_kind,
      zabbix_host: build_host_data(node.zabbix_host),
      metrics: node.map_node_items.map { |mni| build_metric(mni) }
    }
  end

  def build_host_data(host)
    return nil unless host

    {
      id: host.id,
      hostid: host.hostid,
      name: host.name,
      status: host.status,
      available: host.available,
      last_seen_at: host.last_seen_at
    }
  end

  def build_metric(map_node_item)
    item = map_node_item.zabbix_item

    {
      map_node_item_id: map_node_item.id,
      alias: map_node_item.alias,
      display_order: map_node_item.display_order,
      itemid: item.itemid,
      name: item.name,
      key_: item.key_,
      value_type: item.value_type,
      units: item.units,
      status: item.status,
      state: item.state,
      lastvalue: item.lastvalue,
      lastclock: item.lastclock
    }
  end
end
