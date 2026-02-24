require "test_helper"

class MapNodeTest < ActiveSupport::TestCase
  test "resolves map_pop_id from external_id" do
    organization = Organization.create!(name: "Org Node")
    network_map = organization.network_maps.create!(name: "Mapa Node", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.0, lng: -46.0, color: "#7c3aed")

    node = network_map.map_nodes.create!(
      label: "Switch A",
      node_kind: "switch",
      x: 10,
      y: 20,
      map_pop_id: pop.external_id
    )

    assert_equal pop.id, node.map_pop_id
    assert_equal pop.external_id, node.map_pop.external_id
  end
end
