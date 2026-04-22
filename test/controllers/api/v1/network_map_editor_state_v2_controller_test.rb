require "test_helper"

class Api::V1::NetworkMapEditorStateV2ControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "editorstate@example.com", password: "password", password_confirmation: "password")
    @organization = Organization.create!(name: "Org Editor", slug: "org-editor")
    Membership.create!(user: @user, organization: @organization, role: "admin")
    @network_map = NetworkMap.create!(organization: @organization, name: "Editor Map")
    @map_pop = @network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: 1, lng: 1)
    @site = Site.create!(organization: @organization, name: "Site A", slug: "site-a")
    @device = Device.create!(organization: @organization, site: @site, name: "SW-01", role: "switch", status: "active")
    @network_map.map_nodes.create!(mappable: @site, map_pop: @map_pop, label: @site.name, node_kind: "gateway", x: 1, y: 1, lat: 1, lng: 1, icon: "pi-building", color: "#111111", size: 30)
    @network_map.map_nodes.create!(mappable: @device, label: @device.name, node_kind: "switch", x: 2, y: 2, lat: 2, lng: 2, icon: "pi-box", color: "#222222", size: 30)

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "password", organization_id: @organization.id } }
    @auth_headers = response.headers.slice("Authorization")
  end

  test "editor_state returns only site markers as renderable elements" do
    get "/api/v1/network_maps/#{@network_map.id}/editor_state", params: { organization_id: @organization.id }, headers: @auth_headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.dig("data", "elements").size
    assert_equal "Site", body.dig("data", "elements", 0, "mappable_type")
    assert_equal "pop-a", body.dig("data", "elements", 0, "pop_id")
    assert_equal @map_pop.id, body.dig("data", "elements", 0, "map_pop_id")
    assert_equal 1, body.dig("data", "devices").size
    assert_equal 1, body.dig("data", "sites").size
  end

  test "editor_state highlights site color when icmp ping is up" do
    zabbix_connection = ZabbixConnection.create!(
      organization: @organization,
      name: "Conn Ping",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )

    host = zabbix_connection.zabbix_hosts.create!(
      hostid: "10001",
      name: "Site A Host"
    )

    ping_item = zabbix_connection.zabbix_items.create!(
      itemid: "20001",
      host: host,
      name: "ICMP Ping",
      key_: "icmpping",
      value_type: "3",
      units: "",
      status: "0",
      state: "0",
      lastvalue: "1",
      lastclock: "1700000000"
    )

    site_node = @network_map.map_nodes.find_by!(mappable: @site)
    site_node.map_node_items.create!(zabbix_item: ping_item, alias: "ICMP Ping", display_order: 0)

    get "/api/v1/network_maps/#{@network_map.id}/editor_state", params: { organization_id: @organization.id }, headers: @auth_headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "#00c853", body.dig("data", "elements", 0, "color_override")
    assert_equal "up", body.dig("data", "elements", 0, "monitoring_ping", "status")
  end

  test "editor_state marks site down when ping is up but loss is 100 percent" do
    zabbix_connection = ZabbixConnection.create!(
      organization: @organization,
      name: "Conn Ping Loss",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )

    host = zabbix_connection.zabbix_hosts.create!(
      hostid: "10011",
      name: "Site A Host"
    )

    ping_item = zabbix_connection.zabbix_items.create!(
      itemid: "21001",
      host: host,
      name: "ICMP Ping",
      key_: "icmpping",
      value_type: "3",
      units: "",
      status: "0",
      state: "0",
      lastvalue: "1",
      lastclock: "1700000010"
    )

    loss_item = zabbix_connection.zabbix_items.create!(
      itemid: "21002",
      host: host,
      name: "ICMP loss",
      key_: "icmppingloss",
      value_type: "3",
      units: "%",
      status: "0",
      state: "0",
      lastvalue: "100",
      lastclock: "1700000010"
    )

    site_node = @network_map.map_nodes.find_by!(mappable: @site)
    site_node.map_node_items.create!(zabbix_item: ping_item, alias: "ICMP Ping", display_order: 0)
    site_node.map_node_items.create!(zabbix_item: loss_item, alias: "ICMP Loss", display_order: 1)

    get "/api/v1/network_maps/#{@network_map.id}/editor_state", params: { organization_id: @organization.id }, headers: @auth_headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "down", body.dig("data", "elements", 0, "monitoring_ping", "status")
    assert_equal "loss_100", body.dig("data", "elements", 0, "monitoring_ping", "reason")
    assert_equal "1", body.dig("data", "elements", 0, "monitoring_ping", "metrics", "ping", "lastvalue")
    assert_equal "100", body.dig("data", "elements", 0, "monitoring_ping", "metrics", "loss", "lastvalue")
  end
end
