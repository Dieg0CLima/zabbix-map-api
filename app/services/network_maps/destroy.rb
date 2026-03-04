class NetworkMaps::Destroy
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    @network_map.destroy!
  end
end
