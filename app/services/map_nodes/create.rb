class MapNodes::Create
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    map_node = @network_map.map_nodes.new(@payload)
    map_node.save!
    map_node
  end
end
