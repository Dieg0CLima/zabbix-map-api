require "test_helper"

class MapPops::DestroyTest < ActiveSupport::TestCase
  test "destroys pop without dependencies" do
    organization = Organization.create!(name: "Org MP Destroy")
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual")
    map_pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#7c3aed")

    MapPops::Destroy.new(map_pop:).call

    assert_not MapPop.exists?(map_pop.id)
  end
end
