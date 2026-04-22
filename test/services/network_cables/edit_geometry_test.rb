require "test_helper"

class NetworkCables::EditGeometryTest < ActiveSupport::TestCase
  test "remove_segment removes selected range and bumps geometry_version" do
    cable, network_map = build_cable_with_points(points: 5)

    updated = NetworkCables::EditGeometry.new(
      cable: cable,
      network_map: network_map,
      payload: {
        operation: "remove_segment",
        geometry_version: 0,
        from_position: 1,
        to_position: 2
      },
      actor_email: "editor@example.com"
    ).call

    assert_equal [ 0, 1, 2 ], updated.network_cable_points.order(:position).pluck(:position)
    assert_equal 1, updated.metadata["geometry_version"]
    assert_equal "geometry_changed", updated.network_cable_events.last.event_type
  end

  test "raises geometry conflict when version is stale" do
    cable, network_map = build_cable_with_points(points: 4)
    cable.update!(metadata: { "geometry_version" => 2 })

    error = assert_raises(NetworkCables::Errors::GeometryConflict) do
      NetworkCables::EditGeometry.new(
        cable: cable,
        network_map: network_map,
        payload: {
          operation: "remove_point",
          geometry_version: 1,
          position: 2
        },
        actor_email: "editor@example.com"
      ).call
    end

    assert_equal "geometry_conflict", error.code
    assert_equal 1, error.details[:expected_version]
    assert_equal 2, error.details[:current_version]
  end

  test "attach_endpoint_to_pop rebinds source endpoint and snaps first point" do
    cable, network_map = build_cable_with_points(points: 3)
    endpoint_node = network_map.map_nodes.create!(
      external_id: "endpoint-node",
      label: "Endpoint Node",
      node_kind: "generic",
      x: 0.0,
      y: 0.0,
      lat: 0.0,
      lng: 0.0
    )
    destination_pop = network_map.map_pops.create!(
      name: "POP Destino",
      external_id: "pop-dest",
      lat: -23.555,
      lng: -46.666,
      color: "#7c3aed"
    )
    cable.update!(source_node: endpoint_node, source_pop: nil)

    updated = NetworkCables::EditGeometry.new(
      cable: cable,
      network_map: network_map,
      payload: {
        operation: "attach_endpoint_to_pop",
        geometry_version: 0,
        side: "source",
        pop_id: destination_pop.external_id
      },
      actor_email: "editor@example.com"
    ).call

    first_point = updated.network_cable_points.order(:position).first

    assert_equal destination_pop.id, updated.source_pop_id
    assert_nil updated.source_node_id
    assert_equal destination_pop.lat.to_f, first_point.x.to_f
    assert_equal destination_pop.lng.to_f, first_point.y.to_f
    assert_equal 1, updated.metadata["geometry_version"]
  end

  private

  def build_cable_with_points(points:)
    organization = Organization.create!(name: "Org Geometry #{SecureRandom.hex(4)}")
    network_map = organization.network_maps.create!(name: "Mapa Geometry", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#7c3aed")
    cable = network_map.network_cables.create!(source_pop: pop, status: "planned", label: "Fibra A")
    points.times { |index| cable.network_cable_points.create!(position: index, x: index, y: index) }
    [ cable, network_map ]
  end
end
