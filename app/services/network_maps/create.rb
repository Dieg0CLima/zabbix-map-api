class NetworkMaps::Create
  def initialize(organization:, payload:)
    @organization = organization
    @payload = payload
  end

  def call
    network_map = @organization.network_maps.new(@payload)
    network_map.save!
    network_map
  end
end
