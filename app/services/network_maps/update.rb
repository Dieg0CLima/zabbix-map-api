class NetworkMaps::Update
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    @network_map.update!(@payload)
    @network_map
  end
end
