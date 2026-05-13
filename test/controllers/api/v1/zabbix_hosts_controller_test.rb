require "test_helper"

class Api::V1::ZabbixHostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Hosts API", slug: "org-hosts-api-#{SecureRandom.hex(4)}")
    @user = User.create!(email: "hosts.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
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

  test "dropdown returns mapped hosts with meta" do
    fake_result = [
      {
        value: "10105",
        label: "OLT-POP-CENTRO",
        hostid: "10105",
        name: "OLT-POP-CENTRO",
        status: "enabled",
        available: true,
        metadata: {
          interfaces: [ { ip: "10.10.10.1", dns: "", type: "snmp", main: true } ],
          groups: [ { groupid: "8", name: "OLT" } ],
          templates: [ { templateid: "19", name: "Template SNMP" } ]
        }
      }
    ]

    fetcher = Struct.new(:result) do
      def call
        result
      end
    end.new(fake_result)

    fetcher_factory = ->(**_kwargs) { fetcher }
    ZabbixConnections::HostDropdownFetcher.stub(:new, fetcher_factory) do
      get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/dropdown", params: {
        organization_id: @organization.id
      }, headers: auth_headers.merge("Accept" => "application/json")
    end

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
    fake_result = [
      {
        value: "10634",
        label: "SWCX-001-001-005-CENTRAL",
        hostid: "10634",
        name: "SWCX-001-001-005-CENTRAL",
        status: "enabled",
        available: true,
        metadata: { interfaces: [], groups: [], templates: [] }
      }
    ]

    fetcher = Struct.new(:result) do
      def call
        result
      end
    end.new(fake_result)

    fetcher_factory = ->(**_kwargs) { fetcher }
    ZabbixConnections::HostDropdownFetcher.stub(:new, fetcher_factory) do
      get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/dropdown", params: {
        organization_id: @organization.id,
        q: "SWCX"
      }, headers: auth_headers.merge("Accept" => "application/json")
    end

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal 1, body.dig("meta", "total")
    assert_equal "SWCX-001-001-005-CENTRAL", body.dig("data", 0, "label")
  end

  test "show returns host details fetched from zabbix database" do
    payload = {
      hostid: "10572",
      name: "HOST-CORE-BRASILIA",
      host: "core-bsb-01",
      status: "enabled",
      available: true,
      interfaces: [ { ip: "10.0.0.1", dns: "", type: "snmp", main: true } ],
      inventory: { vendor: "Huawei", model: "S5720" },
      metadata: {
        host: "core-bsb-01",
        groups: [ { groupid: "4", name: "Core" } ],
        templates: [ { templateid: "22", name: "Base Template" } ]
      },
      suggested_device_attributes: {
        name: "HOST-CORE-BRASILIA",
        hostname: "core-bsb-01",
        management_ip: "10.0.0.1",
        vendor: "Huawei",
        model: "S5720"
      }
    }

    fetcher = Struct.new(:result) do
      def call
        result
      end
    end.new(payload)

    fetcher_factory = ->(**_kwargs) { fetcher }
    Zabbix::HostDetailsFetcher.stub(:new, fetcher_factory) do
      get "/api/v1/zabbix_connections/#{@connection.id}/zabbix_hosts/10572", params: {
        organization_id: @organization.id
      }, headers: auth_headers.merge("Accept" => "application/json")
    end

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
