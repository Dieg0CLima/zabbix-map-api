require "test_helper"

class NetworkCables::EventStateBuilderTest < ActiveSupport::TestCase
  test "builds state sorted by point position" do
    organization = Organization.create!(name: "Org Event State")
    network_map = organization.network_maps.create!(name: "Mapa Event State", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#000000")

    cable = network_map.network_cables.create!(source_pop: pop, status: "active")
    cable.network_cable_points.create!(position: 2, x: 20, y: 20)
    cable.network_cable_points.create!(position: 1, x: 10, y: 10)

    state = NetworkCables::EventStateBuilder.call(cable:)

    assert_equal "active", state[:status]
    assert_equal [ [ 1, 10.0, 10.0 ], [ 2, 20.0, 20.0 ] ], state[:points]
  end
end
