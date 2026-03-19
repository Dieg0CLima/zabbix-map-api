require "test_helper"

class Api::V1::ZabbixHostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Hosts API", slug: "org-hosts-api-#{SecureRandom.hex(4)}")
    @user = User.create!(email: "hosts.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    @connection = @organization.zabbix_connections.create!(
      name: "Conn",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
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

  test "dropdown returns mapped hosts with meta" do
    @connection.zabbix_hosts.create!(
      hostid: "10105",
      name: "OLT-POP-CENTRO",
      available: "1",
      status: "0",
      interfaces: [{ ip: "10.10.10.1", type: "2", main: "1" }],
      metadata: { groups: [{ groupid: "8", name: "OLT" }], templates: [{ templateid: "19", name: "Template SNMP" }] }
    )

    get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/dropdown", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal @connection.id, body.dig("meta", "connection_id")
    assert_equal 1, body.dig("meta", "total")
    assert_equal "10105", body.dig("data", 0, "value")
    assert_equal "OLT-POP-CENTRO", body.dig("data", 0, "label")
    assert_equal "enabled", body.dig("data", 0, "status")
    assert_equal true, body.dig("data", 0, "available")
    assert_equal "10.10.10.1", body.dig("data", 0, "metadata", "interfaces", 0, "ip")
  end

  test "dropdown filters hosts by query" do
    @connection.zabbix_hosts.create!(hostid: "10634", name: "SWCX-001-001-005-CENTRAL", available: "1")
    @connection.zabbix_hosts.create!(hostid: "10106", name: "MikroTik RB260GS by SNMP", available: "1")

    get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/dropdown", params: {
      organization_id: @organization.id,
      q: "SWCX"
    }, headers: auth_headers, as: :json

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal 1, body.dig("meta", "total")
    assert_equal "SWCX-001-001-005-CENTRAL", body.dig("data", 0, "label")
  end

  test "show returns host details with suggested device attributes" do
    @connection.zabbix_hosts.create!(
      hostid: "10572",
      name: "HOST-CORE-BRASILIA",
      status: "0",
      available: "1",
      interfaces: [{ ip: "10.0.0.1", dns: "", type: "2", main: "1" }],
      metadata: {
        host: "core-bsb-01",
        inventory: { vendor: "Huawei", model: "S5720" },
        groups: [{ groupid: "4", name: "Core" }],
        templates: [{ templateid: "22", name: "Base Template" }]
      }
    )

    get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/10572", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal "HOST-CORE-BRASILIA", body.dig("data", "name")
    assert_equal "core-bsb-01", body.dig("data", "host")
    assert_equal true, body.dig("data", "available")
    assert_equal "10.0.0.1", body.dig("data", "suggested_device_attributes", "management_ip")
    assert_equal "Huawei", body.dig("data", "suggested_device_attributes", "vendor")
    assert_equal "S5720", body.dig("data", "suggested_device_attributes", "model")
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
