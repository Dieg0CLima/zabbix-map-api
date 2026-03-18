class Zabbix::MetricsFetcher
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    @network_map.map_nodes.includes(:monitoring_bindings).map do |node|
      {
        map_node_id: node.id,
        mappable_type: node.mappable_type,
        mappable_id: node.mappable_id,
        bindings_count: node.monitoring_bindings.size
      }
    end
  end
end
