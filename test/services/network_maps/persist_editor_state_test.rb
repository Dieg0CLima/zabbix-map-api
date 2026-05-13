require "test_helper"

class NetworkMaps::PersistEditorStateTest < ActiveSupport::TestCase
  test "upserts records by external_id and keeps internal ids stable" do
    organization = Organization.create!(name: "Org Persist")
    network_map = organization.network_maps.create!(name: "Mapa Persist", source_type: "manual")

    pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.1, lng: -46.1, color: "#7c3aed")
    node = network_map.map_nodes.create!(
      external_id: "node-a", map_pop: pop, label: "OLT A", node_kind: "olt",
      lat: -23.1, lng: -46.1, x: -23.1, y: -46.1, icon: "pi-server", color: "#2563eb", size: 30
    )
    cable = network_map.network_cables.create!(
      external_id: "cable-a", source_pop: pop, source_node: node,
      cable_type: "manual", status: "planned", color: "#0891b2", weight: 4, pattern: "solid"
    )
    cable.network_cable_points.create!(position: 0, x: -23.100001, y: -46.100001)
    cable.network_cable_points.create!(position: 1, x: -23.100002, y: -46.100002)

    service = NetworkMaps::PersistEditorState.new(
      network_map:,
      payload: {
        active_base_layer: "terrain",
        pops: [ { id: "pop-a", name: "POP A Atualizado", lat: -23.11, lng: -46.11, color: "#111111", metadata: { region: "centro" } } ],
        markers: [ { id: "node-a", pop_id: "pop-a", label: "OLT A2", node_kind: "olt", lat: -23.11, lng: -46.11, icon: "pi-server", color: "#222222", size: 32, metadata: {} } ],
        edges: [ { id: "cable-a", source_pop_id: "pop-a", source_node_id: "node-a", cable_type: "feeder", status: "active", color: "#333333", weight: 5, pattern: "dashed", metadata: { fiber_count: 24 }, points: [ { position: 0, lat: -23.110001, lng: -46.110001 }, { position: 1, lat: -23.110002, lng: -46.110002 } ] } ],
        history_label: "Autosave Test",
        history_index: 3
      }
    )

    service.call

    assert_equal pop.id, network_map.map_pops.find_by!(external_id: "pop-a").id
    assert_equal node.id, network_map.map_nodes.find_by!(external_id: "node-a").id
    assert_equal cable.id, network_map.network_cables.find_by!(external_id: "cable-a").id
    assert_equal "terrain", network_map.reload.active_base_layer
  end

  test "removes stale records and validates duplicated external_id" do
    organization = Organization.create!(name: "Org Persist 2")
    network_map = organization.network_maps.create!(name: "Mapa Persist 2", source_type: "manual")

    stale_pop = network_map.map_pops.create!(name: "POP Stale", external_id: "pop-stale", lat: -23.2, lng: -46.2, color: "#7c3aed")
    network_map.map_nodes.create!(
      external_id: "node-stale", map_pop: stale_pop, label: "NODE", node_kind: "switch",
      lat: -23.2, lng: -46.2, x: -23.2, y: -46.2, icon: "pi-server", color: "#2563eb", size: 30
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      NetworkMaps::PersistEditorState.new(
        network_map:,
        payload: {
          pops: [
            { id: "dup-pop", name: "A", lat: -1, lng: -1, color: "#000" },
            { id: "dup-pop", name: "B", lat: -2, lng: -2, color: "#111" }
          ],
          markers: [],
          edges: []
        }
      ).call
    end

    NetworkMaps::PersistEditorState.new(
      network_map:,
      payload: {
        pops: [],
        markers: [],
        edges: []
      }
    ).call

    assert_equal 0, network_map.map_pops.count
    assert_equal 0, network_map.map_nodes.count
    assert_equal 0, network_map.network_cables.count
  end
end
