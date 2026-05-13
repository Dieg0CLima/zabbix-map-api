require "test_helper"

class Api::V1::DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Devices API", slug: "org-devices-api-#{SecureRandom.hex(4)}")
    @site = @organization.sites.create!(name: "Site BSB", slug: "site-bsb-#{SecureRandom.hex(4)}")
    @user = User.create!(email: "devices.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_header = response.headers["Authorization"]
  end

  test "catalogs returns device dropdown options from API" do
    get "/api/v1/devices/catalogs", params: { organization_id: @organization.id }, headers: auth_headers.merge("Accept" => "application/json")

    assert_response :ok

    body = JSON.parse(response.body)
    assert_equal "generic", body.dig("data", "roles", 0, "value")
    assert_equal "Genérico", body.dig("data", "roles", 0, "label")
    assert_equal "active", body.dig("data", "statuses", 1, "value")
    assert_equal "Ativo", body.dig("data", "statuses", 1, "label")
  end

  test "create device accepts zabbix host link payload without local host persistence" do
    connection = @organization.zabbix_connections.create!(name: "Conn Devices", status: "active", connection_mode: "database", db_adapter: "postgresql", db_host: "127.0.0.1", db_port: 5432, db_name: "zabbix", db_username: "zabbix", db_password: "secret")

    reference_payload = {
      hostid: "10572",
      name: "HOST-CORE-BRASILIA",
      status: "enabled",
      available: true,
      interfaces: [ { ip: "10.0.0.1", dns: "", type: "snmp", main: true } ],
      metadata: { host: "core-bsb-01", inventory: { vendor: "Huawei", model: "S5720" } }
    }

    fetcher = Minitest::Mock.new
    fetcher.expect(:reference_payload, reference_payload)

    Zabbix::HostDetailsFetcher.stub(:new, fetcher) do
      post "/api/v1/devices", params: {
        organization_id: @organization.id,
        device: {
          site_id: @site.id,
          name: "Core Brasília",
          hostname: "core-bsb-01",
          role: "switch",
          status: "active",
          vendor: "Huawei",
          model: "S5720",
          management_ip: "10.0.0.1",
          zabbix_connection_id: connection.id,
          zabbix_host_id: "10572"
        }
      }, headers: auth_headers, as: :json
    end

    fetcher.verify

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal connection.id, body.dig("data", "device", "zabbix_connection_id")
    assert_equal "10572", body.dig("data", "device", "zabbix_host_id")
    assert_equal "HOST-CORE-BRASILIA", body.dig("data", "device", "zabbix_host", "label")
    assert_equal 0, connection.zabbix_hosts.count
  end

  test "update device validates incomplete zabbix link payload" do
    device = @organization.devices.create!(site: @site, name: "Edge", role: "generic", status: "active")

    patch "/api/v1/devices/#{device.id}", params: {
      organization_id: @organization.id,
      device: {
        zabbix_host_id: "10572"
      }
    }, headers: auth_headers, as: :json

    assert_response :unprocessable_entity

    body = JSON.parse(response.body)
    assert_equal "zabbix_connection_id and zabbix_host_id must be provided together", body.dig("errors", 0, "detail")
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
