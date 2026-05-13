require "test_helper"

class NetworkMaps::EditorStatePayloadBuilderTest < ActiveSupport::TestCase
  test "builds a complete editor payload" do
    organization = Organization.create!(name: "Org Builder")
    network_map = organization.network_maps.create!(name: "Mapa Builder", source_type: "manual", active_base_layer: "satellite")

    pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.1, lng: -46.1, color: "#7c3aed", metadata: { owner: "ops" })
    node = network_map.map_nodes.create!(
      external_id: "node-a", map_pop: pop, label: "Node A", node_kind: "switch",
      lat: -23.2, lng: -46.2, x: -23.2, y: -46.2, icon: "pi-server", color: "#2563eb", size: 30, metadata: { rack: "r1" }
    )
    cable = network_map.network_cables.create!(
      external_id: "cable-a", label: "Cabo A", source_pop: pop, source_node: node,
      cable_type: "manual", status: "planned", color: "#0891b2", weight: 4, pattern: "solid", metadata: { fiber_count: 24 }
    )
    cable.network_cable_points.create!(position: 1, x: -23.200002, y: -46.200002)
    cable.network_cable_points.create!(position: 0, x: -23.200001, y: -46.200001)

    old_snapshot = network_map.network_map_snapshots.create!(label: "Old", state: { history_index: 1 }, created_at: 2.days.ago)
    latest_snapshot = network_map.network_map_snapshots.create!(
      label: "Latest",
      state: { history_index: 3, draft_cable: { source_id: "node-a" } },
      created_at: 1.day.ago
    )

    payload = NetworkMaps::EditorStatePayloadBuilder.new(network_map:).call

    assert_equal network_map.id, payload[:network_map_id]
    assert_equal "satellite", payload[:active_base_layer]
    assert_equal "Latest", payload[:history_label]
    assert_equal 3, payload[:history_index]
    assert_equal({ "source_id" => "node-a" }, payload[:draft_cable])

    assert_equal [ "pop-a" ], payload[:pops].map { |item| item[:id] }
    assert_equal [ "node-a" ], payload[:markers].map { |item| item[:id] }
    assert_equal [ "cable-a" ], payload[:edges].map { |item| item[:id] }

    assert_equal [ 0, 1 ], payload[:edges].first[:points].map { |point| point[:position] }
    assert_equal [ latest_snapshot.id, old_snapshot.id ], payload[:snapshots].map { |snapshot| snapshot[:id] }
  end

  test "returns empty history details when map has no snapshots" do
    organization = Organization.create!(name: "Org Empty")
    network_map = organization.network_maps.create!(name: "Mapa Empty", source_type: "manual")

    payload = NetworkMaps::EditorStatePayloadBuilder.new(network_map:).call

    assert_nil payload[:history_label]
    assert_nil payload[:history_index]
    assert_nil payload[:draft_cable]
    assert_equal [], payload[:snapshots]
  end
end
