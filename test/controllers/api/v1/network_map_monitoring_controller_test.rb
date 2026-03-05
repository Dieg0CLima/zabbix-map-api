require "test_helper"

class Api::V1::NetworkMapMonitoringControllerTest < ActionDispatch::IntegrationTest
  test "returns monitoring snapshot for map" do
    organization = Organization.create!(name: "Org Monitoring API")
    connection = organization.zabbix_connections.create!(name: "Zabbix Main", connection_mode: "api")
    map = organization.network_maps.create!(name: "Map Monitor", source_type: "manual", zabbix_connection: connection)
    site = organization.sites.create!(name: "Site M", external_id: "site-m", status: "active")
    device = organization.devices.create!(name: "Device M", external_id: "device-m", site:, device_type: "switch", zabbix_ref: "10084", status: "active")
    link = organization.network_links.create!(external_id: "link-m", source_device: device, link_type: "logical", zabbix_item_ref: "29876", status: "active")

    pop = map.map_pops.create!(name: "POP M", external_id: "pop-m", lat: -23.0, lng: -46.0, color: "#7c3aed", site:)
    node = map.map_nodes.create!(label: "Node M", node_kind: "switch", x: 10, y: 20, map_pop: pop, device:)
    map.network_cables.create!(source_pop: pop, source_node: node, cable_type: "manual", status: "planned", network_link: link)

    Zabbix::Host.create!(zabbix_connection: connection, hostid: "10084", name: "Host M", status: "0", available: "1")
    Zabbix::Item.create!(zabbix_connection: connection, itemid: "29876", name: "Traffic", key_: "net.if.in", lastvalue: "1500000", units: "bps")

    user = User.create!(email: "monitor.viewer@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "viewer")

    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: organization.id } }, as: :json
    auth_header = response.headers["Authorization"]

    get "/api/v1/network_maps/#{map.id}/monitoring", params: { organization_id: organization.id }, headers: { "Authorization" => auth_header }, as: :json

    assert_response :ok
    assert_equal "10084", response.parsed_body.dig("data", "nodes", 0, "zabbix_data", "hostid")
    assert_equal "29876", response.parsed_body.dig("data", "cables", 0, "zabbix_data", "itemid")
  end
end
