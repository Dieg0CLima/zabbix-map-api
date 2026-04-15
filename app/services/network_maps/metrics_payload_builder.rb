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
    nodes = @network_map.map_nodes
                        .includes(:zabbix_host, map_node_items: :zabbix_item)
                        .order(:id)
    history = fetch_live_history(nodes)
    nodes.map { |node| build_node_metrics(node, history) }
  end

  def fetch_live_history(nodes)
    connection = @network_map.zabbix_connection
    return {} unless connection&.db_enabled?

    loaded_items = nodes.flat_map { |node| node.map_node_items.select { |mni| mni.zabbix_item.present? } }
    return {} if loaded_items.empty?

    itemids        = loaded_items.map { |mni| mni.zabbix_item.itemid }.uniq
    value_type_map = loaded_items.each_with_object({}) { |mni, h| h[mni.zabbix_item.itemid.to_s] = mni.zabbix_item.value_type.to_s }

    Zabbix::HistoryCache.new(connection: connection, itemids: itemids, value_type_map: value_type_map).fetch
  rescue StandardError
    {}
  end

  def build_node_metrics(node, history = {})
    {
      id: node.external_id || node.id,
      external_id: node.external_id,
      label: node.label,
      node_kind: node.node_kind,
      zabbix_host: build_host_data(node.zabbix_host),
      metrics: node.map_node_items.map { |mni| build_metric(mni, history) }
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

  def build_metric(map_node_item, history = {})
    item = map_node_item.zabbix_item
    live = history[item.itemid.to_s] if item && history.any?

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
      lastvalue: live&.dig("value") || item.lastvalue,
      lastclock: live&.dig("clock") || item.lastclock
    }
  end
end
