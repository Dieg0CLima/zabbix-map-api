require "test_helper"

class Api::V1::Sites::Monitoring::PingLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Site Ping", slug: "org-site-ping")
    @user = User.create!(email: "site.ping@example.com", password: "password", password_confirmation: "password")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    @connection = @organization.zabbix_connections.create!(
      name: "Main Conn",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.example.com"
    )

    @network_map = @organization.network_maps.create!(
      name: "Mapa Site Ping",
      source_type: "manual",
      zabbix_connection: @connection
    )

    @site = @organization.sites.create!(
      name: "POP Centro",
      slug: "pop-centro"
    )

    @site_node = @network_map.map_nodes.create!(
      mappable: @site,
      label: @site.name,
      node_kind: "generic",
      x: -46.63,
      y: -23.55,
      lat: -23.55,
      lng: -46.63,
      icon: "pi-map-marker",
      color: "#2563eb",
      size: 30,
      external_id: "site-#{@site.id}",
      metadata: {}
    )

    @device = @organization.devices.create!(
      site: @site,
      name: "Router POP",
      role: "router",
      status: "active"
    )

    @zabbix_link = @organization.zabbix_links.create!(
      zabbix_connection: @connection,
      linkable: @device,
      resource_type: "host",
      external_id: "10001",
      name: "Router POP Host"
    )

    @host = @connection.zabbix_hosts.create!(
      hostid: @zabbix_link.external_id,
      name: "Router POP Host",
      status: "0",
      available: "1"
    )

    @icmp_item = @connection.zabbix_items.create!(
      zabbix_host: @host,
      itemid: "30001",
      name: "ICMP ping",
      key_: "icmpping",
      value_type: "3",
      units: "",
      status: "0",
      state: "0",
      lastvalue: "1",
      lastclock: Time.current
    )

    @icmp_loss_item = @connection.zabbix_items.create!(
      zabbix_host: @host,
      itemid: "30003",
      name: "ICMP loss",
      key_: "icmppingloss",
      value_type: "3",
      units: "%",
      status: "0",
      state: "0",
      lastvalue: "5",
      lastclock: Time.current
    )

    @icmp_response_time_item = @connection.zabbix_items.create!(
      zabbix_host: @host,
      itemid: "30004",
      name: "ICMP response time",
      key_: "icmppingsec",
      value_type: "0",
      units: "s",
      status: "0",
      state: "0",
      lastvalue: "0.010",
      lastclock: Time.current
    )

    @non_icmp_item = @connection.zabbix_items.create!(
      zabbix_host: @host,
      itemid: "30002",
      name: "System uptime",
      key_: "system.uptime",
      value_type: "3",
      units: "s",
      status: "0",
      state: "0",
      lastvalue: "123",
      lastclock: Time.current
    )

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "password",
        organization_id: @organization.id
      }
    }, as: :json
    @auth_header = response.headers["Authorization"]
  end

  test "creates site ping link with icmp item" do
    post create_path, params: {
      monitoring_ping_link: {
        device_id: @device.id,
        zabbix_item_id: @icmp_item.id
      }
    }, headers: auth_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)

    assert_equal @icmp_item.id, body.dig("data", "linked_item", "zabbix_item_id")
    assert_equal @site_node.id, body.dig("data", "linked_item", "map_node_id")
    assert_equal 1, @site_node.reload.map_node_items.count
  end

  test "show returns icmp candidates for site devices" do
    get show_path, headers: auth_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    candidate = body.dig("data", "candidates").find { |entry| entry["zabbix_item_id"] == @icmp_item.id }
    loss_candidate = body.dig("data", "candidates").find { |entry| entry["zabbix_item_id"] == @icmp_loss_item.id }

    assert_not_nil candidate
    assert_equal @device.id, candidate.dig("device", "id")
    assert_equal "ping", candidate["metric_kind"]
    assert_not_nil loss_candidate
    assert_equal "loss", loss_candidate["metric_kind"]
  end

  test "show returns candidates even when local zabbix_host cache is missing" do
    @host.destroy!
    @icmp_item.update!(zabbix_host: nil)

    get show_path, headers: auth_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_empty body.dig("data", "candidates")
  end

  test "rejects non icmp item link" do
    post create_path, params: {
      monitoring_ping_link: {
        device_id: @device.id,
        zabbix_item_id: @non_icmp_item.id
      }
    }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "zabbix_item_id", body.dig("errors", 0, "source")
  end

  test "destroy removes current site ping links" do
    @site_node.map_node_items.create!(zabbix_item: @icmp_item, alias: "ICMP Ping", display_order: 0)

    delete show_path, headers: auth_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 1, body.dig("data", "removed_count")
    assert_equal 0, @site_node.reload.map_node_items.count
  end

  test "create keeps different icmp metric kinds linked on same site node" do
    post create_path, params: {
      monitoring_ping_link: {
        device_id: @device.id,
        zabbix_item_id: @icmp_item.id
      }
    }, headers: auth_headers, as: :json

    assert_response :ok

    post create_path, params: {
      monitoring_ping_link: {
        device_id: @device.id,
        zabbix_item_id: @icmp_loss_item.id
      }
    }, headers: auth_headers, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 0, body.dig("data", "replaced_count")
    assert_equal 2, @site_node.reload.map_node_items.count
  end

  private

  def show_path
    "/api/v1/network_maps/#{@network_map.id}/sites/#{@site.id}/monitoring/ping-link"
  end

  def create_path
    show_path
  end

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
