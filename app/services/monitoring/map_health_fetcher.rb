class Monitoring::MapHealthFetcher
  def initialize(network_map:, scope: nil)
    @network_map = network_map
    @scope = scope
  end

  def call
    nodes = Array(@scope || NetworkMaps::RenderableElementsQuery.new(network_map: @network_map).call)

    {
      total_sites: nodes.count,
      monitored_sites: nodes.count { |node| node.monitoring_bindings.any? },
      unmonitored_sites: nodes.count { |node| node.monitoring_bindings.none? }
    }
  end
end
