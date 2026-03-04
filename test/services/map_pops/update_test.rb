require "test_helper"

class MapPops::UpdateTest < ActiveSupport::TestCase
  test "updates pop attributes" do
    organization = Organization.create!(name: "Org MP Update")
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual")
    map_pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#7c3aed")

    updated = MapPops::Update.new(map_pop:, payload: { name: "POP 2" }).call

    assert_equal "POP 2", updated.name
  end
end
