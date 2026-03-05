require "test_helper"

class NetworkMaps::MonitoringPayloadBuilderTest < ActiveSupport::TestCase
  test "prefers device zabbix_ref over map node and resolves link items" do
    organization = Organization.create!(name: "Org Monitoring Builder")
    connection = organization.zabbix_connections.create!(name: "Zbx", connection_mode: "api")
    map = organization.network_maps.create!(name: "Map", source_type: "manual", zabbix_connection: connection)

    site = organization.sites.create!(name: "Site", status: "active")
    pop = map.map_pops.create!(name: "POP", lat: -23, lng: -46, color: "#7c3aed", site:)

    device = organization.devices.create!(name: "Device", device_type: "switch", status: "active", zabbix_ref: "10084")
    node = map.map_nodes.create!(label: "Node", node_kind: "switch", x: 0, y: 0, map_pop: pop, device:, zabbix_ref: "99999")

    link = organization.network_links.create!(source_site: site, link_type: "logical", status: "active", zabbix_item_ref: "29876")
    map.network_cables.create!(source_pop: pop, source_node: node, cable_type: "manual", status: "planned", network_link: link)

    Zabbix::Host.create!(zabbix_connection: connection, hostid: "10084", name: "Host", status: "0", available: "1")
    Zabbix::Item.create!(zabbix_connection: connection, itemid: "29876", name: "Traffic", key_: "k", lastvalue: "1", units: "bps")

    payload = NetworkMaps::MonitoringPayloadBuilder.new(network_map: map).call

    assert_equal map.id, payload[:network_map_id]
    assert_equal "10084", payload[:nodes].first[:zabbix_data][:hostid]
    assert_equal "29876", payload[:cables].first[:zabbix_data][:itemid]
  end
end
