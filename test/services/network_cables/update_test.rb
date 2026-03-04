require "test_helper"

class NetworkCables::UpdateTest < ActiveSupport::TestCase
  test "updates cable and records inferred geometry_changed event" do
    organization = Organization.create!(name: "Org Cable Update")
    network_map = organization.network_maps.create!(name: "Mapa Update", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#7c3aed")
    cable = network_map.network_cables.create!(source_pop: pop, status: "planned", label: "Cabo")
    cable.network_cable_points.create!(position: 0, x: 0, y: 0)
    cable.network_cable_points.create!(position: 1, x: 1, y: 1)

    updated = NetworkCables::Update.new(
      cable:,
      network_map:,
      payload: {
        status: "planned",
        points: [
          { position: 0, x: 0, y: 0 },
          { position: 1, x: 2, y: 2 }
        ]
      },
      actor_email: "editor@example.com",
      points_provided: true
    ).call

    assert_equal 2, updated.network_cable_points.count
    assert_equal "geometry_changed", updated.network_cable_events.last.event_type
  end
end
