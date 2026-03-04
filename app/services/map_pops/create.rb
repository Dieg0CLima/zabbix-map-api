class MapPops::Create
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    map_pop = @network_map.map_pops.new(@payload)
    map_pop.save!
    map_pop
  end
end
