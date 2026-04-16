require "test_helper"

class Api::V1::Devices::Monitoring::AvailableItemsControllerTest < ActionDispatch::IntegrationTest
  test "returns paginated available items with query metadata" do
    organization = Organization.create!(name: "Org Device Monitoring")
    user = User.create!(email: "devices.monitoring@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    connection = organization.zabbix_connections.create!(
      name: "Zabbix Conn",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.example.com"
    )
    device = organization.devices.create!(name: "Edge Device", role: "router", status: "active")
    ZabbixLink.create!(
      organization: organization,
      zabbix_connection: connection,
      linkable: device,
      resource_type: "host",
      external_id: "host-42",
      name: "Host 42",
      metadata: { hostid: "host-42" }
    )
    Devices::MonitoringProfileSync.new(device: device).call

    connection.zabbix_items.create!(
      itemid: "100",
      name: "Traffic In",
      key_: "net.if.in",
      value_type: "3",
      units: "bps",
      status: "0"
    )
    connection.zabbix_items.create!(
      itemid: "200",
      name: "Traffic Out",
      key_: "net.if.out",
      value_type: "3",
      units: "bps",
      status: "0"
    )
    connection.zabbix_items.create!(
      itemid: "300",
      name: "CPU Load",
      key_: "system.cpu.load",
      value_type: "3",
      units: "%",
      status: "0"
    )

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json
    auth_header = response.headers["Authorization"]

    get "/api/v1/devices/#{device.id}/monitoring/available-items",
        params: { organization_id: organization.id, q: "traffic", page: 2, per_page: 1 },
        headers: { "Authorization" => auth_header },
        as: :json

    assert_response :ok
    payload = response.parsed_body

    assert_equal 1, payload.fetch("data").size
    assert_equal "Traffic Out", payload.fetch("data").first.fetch("label")

    meta = payload.fetch("meta")
    assert_equal "host-42", meta.fetch("hostid")
    assert_equal 1, meta.fetch("count")
    assert_equal 2, meta.fetch("total_count")
    assert_equal 2, meta.fetch("page")
    assert_equal 1, meta.fetch("per_page")
    assert_equal 2, meta.fetch("total_pages")
    assert_equal false, meta.fetch("has_next_page")
    assert_equal true, meta.fetch("has_prev_page")
    assert_equal "traffic", meta.fetch("query")
  end
end
