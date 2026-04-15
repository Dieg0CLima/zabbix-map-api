require "test_helper"

class Api::V1::MapNodeItemsV2ControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Node Items", slug: "org-node-items")
    @user = User.create!(email: "node.items@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    @connection = @organization.zabbix_connections.create!(
      name: "Main Conn",
      status: "active",
      connection_mode: "database",
      db_adapter: "postgresql",
      db_host: "127.0.0.1",
      db_port: 5432,
      db_name: "zabbix",
      db_username: "zabbix",
      db_password: "secret"
    )

    @host = @connection.zabbix_hosts.create!(
      hostid: "10001",
      name: "SW-01",
      status: "0",
      available: "1"
    )

    @item = @connection.zabbix_items.create!(
      zabbix_host: @host,
      itemid: "30001",
      name: "ifInOctets",
      key_: "net.if.in[1]",
      value_type: "3",
      units: "bps",
      status: "0",
      state: "0",
      lastvalue: "123",
      lastclock: Time.current
    )

    @network_map = @organization.network_maps.create!(
      name: "Map Metrics",
      source_type: "zabbix",
      zabbix_connection: @connection,
      active_base_layer: "standard"
    )

    @node = @network_map.map_nodes.create!(
      label: "Node Metrics",
      node_kind: "switch",
      x: 1,
      y: 1,
      lat: 1,
      lng: 1,
      icon: "pi-server",
      color: "#111111",
      size: 30,
      external_id: "node-metrics",
      metadata: {},
      zabbix_host: @host
    )

    @map_node_item = @node.map_node_items.create!(
      zabbix_item: @item,
      alias: "Bits Received",
      display_order: 1
    )

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_header = response.headers["Authorization"]
  end

  test "metrics returns live values when history is available" do
    history_payload = {
      "30001" => { "value" => "987654", "clock" => "1800000000" }
    }

    cache_stub = Minitest::Mock.new
    cache_stub.expect(:fetch, history_payload)

    stub_factory = ->(**kwargs) { cache_stub }

    Zabbix::HistoryCache.stub(:new, stub_factory) do
      get "/api/v1/network_maps/#{@network_map.id}/nodes/#{@node.id}/node_items/metrics", headers: auth_headers, as: :json
    end

    cache_stub.verify

    assert_response :ok
    body = JSON.parse(response.body)
    metric = body.dig("data", 0)

    assert_equal @map_node_item.id, metric["map_node_item_id"]
    assert_equal "30001", metric["itemid"]
    assert_equal "987654", metric["lastvalue"]
    assert_equal "1800000000", metric["lastclock"]
    assert_equal "live", metric["data_source"]
    assert_equal "987654 bps", metric["display_value"]
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
