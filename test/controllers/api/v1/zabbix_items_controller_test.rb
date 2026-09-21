require "test_helper"

class Api::V1::ZabbixItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Items API", slug: "org-items-api-#{SecureRandom.hex(4)}")
    @user = User.create!(email: "items.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    @connection = @organization.zabbix_connections.create!(
      name: "Conn",
      status: "active",
      connection_mode: "database",
      db_adapter: "postgresql",
      db_host: "127.0.0.1",
      db_port: 5432,
      db_name: "zabbix",
      db_username: "zabbix",
      db_password: "secret"
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

  test "dropdown returns mapped items with meta and host filter" do
    host_a = @connection.zabbix_hosts.create!(hostid: "101", name: "OLT-1")
    host_b = @connection.zabbix_hosts.create!(hostid: "102", name: "OLT-2")

    @connection.zabbix_items.create!(itemid: "1", name: "CPU", key_: "system.cpu", value_type: 3, units: "%", zabbix_host: host_a)
    @connection.zabbix_items.create!(itemid: "2", name: "RAM", key_: "vm.memory", value_type: 3, units: "MB", zabbix_host: host_b)

    get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_items/dropdown", params: {
      organization_id: @organization.id,
      zabbix_host_id: host_a.id
    }, headers: auth_headers.merge("Accept" => "application/json")

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal @connection.id, body.dig("meta", "connection_id")
    assert_equal 1, body.dig("meta", "count")
    assert_equal "1", body.dig("data", 0, "itemid")
    assert_equal "CPU (system.cpu)", body.dig("data", 0, "label")
    assert_equal "%", body.dig("data", 0, "units")
    assert_equal "3", body.dig("data", 0, "value_type")
  end

  test "dropdown returns all items ordered by name when host filter is absent" do
    host = @connection.zabbix_hosts.create!(hostid: "101", name: "OLT-1")

    @connection.zabbix_items.create!(itemid: "2", name: "RAM", key_: "vm.memory", value_type: 3, units: "MB", zabbix_host: host)
    @connection.zabbix_items.create!(itemid: "1", name: "CPU", key_: "system.cpu", value_type: 3, units: "%", zabbix_host: host)

    get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_items/dropdown", params: {
      organization_id: @organization.id
    }, headers: auth_headers.merge("Accept" => "application/json")

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal 2, body.dig("meta", "count")
    assert_equal [ "CPU (system.cpu)", "RAM (vm.memory)" ], body["data"].map { |item| item["label"] }
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
