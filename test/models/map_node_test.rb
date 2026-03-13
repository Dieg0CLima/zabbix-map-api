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

  test "validates zabbix_host belongs to network map connection when present" do
    organization = Organization.create!(name: "Org Node Zabbix")
    connection_a = organization.zabbix_connections.create!(name: "Conn A", status: "active", connection_mode: "api", base_url: "https://zabbix-a.local")
    connection_b = organization.zabbix_connections.create!(name: "Conn B", status: "active", connection_mode: "api", base_url: "https://zabbix-b.local")
    network_map = organization.network_maps.create!(name: "Mapa Zabbix", source_type: "manual", zabbix_connection: connection_a)

    host_from_other_connection = connection_b.zabbix_hosts.create!(hostid: "777", name: "Host B")

    node = network_map.map_nodes.new(
      label: "Switch X",
      node_kind: "switch",
      x: 10,
      y: 20,
      zabbix_host_id: host_from_other_connection.id
    )

    assert_not node.valid?
    assert_includes node.errors[:zabbix_host_id], "must belong to the network map Zabbix connection"
  end
end
