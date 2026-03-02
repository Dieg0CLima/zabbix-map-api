require "test_helper"

class NetworkCables::CreateTest < ActiveSupport::TestCase
  test "creates cable points and event" do
    organization = Organization.create!(name: "Org Cable Service")
    network_map = organization.network_maps.create!(name: "Mapa Service", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.1, lng: -46.1, color: "#7c3aed")

    cable = NetworkCables::Create.new(
      network_map:,
      payload: {
        source_pop_id: source_pop.external_id,
        cable_type: "feeder",
        status: "active",
        points: [
          { position: 0, lat: -23.11, lng: -46.11 },
          { position: 1, lat: -23.12, lng: -46.12 }
        ]
      },
      actor_email: "editor@example.com"
    ).call

    assert cable.persisted?
    assert_equal 2, cable.network_cable_points.count
    assert_equal "created", cable.network_cable_events.last.event_type
  end

  test "validates minimum points" do
    organization = Organization.create!(name: "Org Cable Service 2")
    network_map = organization.network_maps.create!(name: "Mapa Service 2", source_type: "manual")

    error = assert_raises(NetworkCables::Errors::InvalidPoints) do
      NetworkCables::Create.new(
        network_map:,
        payload: { points: [{ position: 0, lat: -23.11, lng: -46.11 }] },
        actor_email: "editor@example.com"
      ).call
    end

    assert_equal({ points: ["É necessário ao menos 2 pontos"] }, error.details)
  end
end
