require "test_helper"

class MapPops::CreateTest < ActiveSupport::TestCase
  test "creates map pop in map" do
    organization = Organization.create!(name: "Org MP Create")
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual")

    map_pop = MapPops::Create.new(
      network_map:,
      payload: { name: "POP A", lat: -23.1, lng: -46.1, color: "#7c3aed" }
    ).call

    assert map_pop.persisted?
    assert_equal network_map.id, map_pop.network_map_id
  end
end
