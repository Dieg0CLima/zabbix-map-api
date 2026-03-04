require "test_helper"

class NetworkMaps::DestroyTest < ActiveSupport::TestCase
  test "destroys network map" do
    organization = Organization.create!(name: "Org NM Destroy")
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual")

    NetworkMaps::Destroy.new(network_map:).call

    assert_not NetworkMap.exists?(network_map.id)
  end
end
