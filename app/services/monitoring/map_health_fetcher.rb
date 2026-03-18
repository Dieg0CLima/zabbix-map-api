class Monitoring::MapHealthFetcher
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    nodes = @network_map.map_nodes.includes(:monitoring_bindings)

    {
      total_nodes: nodes.count,
      monitored_nodes: nodes.count { |node| node.monitoring_bindings.any? },
      unmonitored_nodes: nodes.count { |node| node.monitoring_bindings.none? }
    }
  end
end
