require "test_helper"

class Api::V1::ZabbixHostsControllerTest < ActionDispatch::IntegrationTest
  test "dropdown returns mapped hosts with meta" do
    organization = Organization.create!(name: "Org Hosts API")
    user = User.create!(email: "hosts.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: organization, role: "editor")

    connection = organization.zabbix_connections.create!(
      name: "Conn",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )
    connection.zabbix_hosts.create!(hostid: "10105", name: "OLT-POP-CENTRO", available: "1")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    get "/api/v1/zabbix_connections/#{connection.id}/zabbix_hosts/dropdown", params: {
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal connection.id, body.dig("meta", "connection_id")
    assert_equal 1, body.dig("meta", "total")
    assert_equal "10105", body.dig("data", 0, "value")
    assert_equal "OLT-POP-CENTRO", body.dig("data", 0, "label")
    assert_equal true, body.dig("data", 0, "available")
  end
end
