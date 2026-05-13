require "test_helper"

class Api::V1::NetworkMapsV2ControllerTest < ActionDispatch::IntegrationTest
  test "cable_metrics returns cable items with latest values" do
    organization = Organization.create!(name: "Org Cable Metrics")
    user = User.create!(email: "map.metrics@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Metrics", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.5, lng: -46.6, color: "#0ea5e9")
    cable = network_map.network_cables.create!(source_pop:, label: "Cabo Teste", status: "active", cable_type: "fiber")
    cable.network_cable_points.create!(position: 0, x: -46.6, y: -23.5)
    cable.network_cable_points.create!(position: 1, x: -46.7, y: -23.6)

    zabbix_connection = organization.zabbix_connections.create!(
      name: "Zabbix API",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.example.com"
    )
    zabbix_host = zabbix_connection.zabbix_hosts.create!(hostid: "1001", name: "SW-A")
    zabbix_item = zabbix_connection.zabbix_items.create!(
      zabbix_host: zabbix_host,
      itemid: "64390",
      name: "Interface Bits received",
      key_: "net.if.in[ifHCInOctets.65]",
      units: "bps",
      lastvalue: "803281616",
      lastclock: Time.current
    )
    cable.network_cable_items.create!(zabbix_item: zabbix_item, metric_role: "bandwidth_in", display_order: 0)

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json
    auth_header = response.headers["Authorization"]

    get "/api/v1/network_maps/#{network_map.id}/cable_metrics",
        params: { organization_id: organization.id },
        headers: { "Authorization" => auth_header, "Accept" => "application/json" }

    assert_response :ok

    payload = response.parsed_body.fetch("data")
    first_cable = payload.fetch("cables").first
    first_item = first_cable.fetch("items").first

    assert_equal cable.id, first_cable["id"]
    assert_equal cable.external_id, first_cable["external_id"]
    assert_equal "bandwidth_in", first_item["metric_role"]
    assert_equal "803281616", first_item["lastvalue"]
    assert_equal "64390", first_item["itemid"]
  end
end
