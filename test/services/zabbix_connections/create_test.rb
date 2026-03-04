require "test_helper"

class ZabbixConnections::CreateTest < ActiveSupport::TestCase
  test "creates api-mode connection" do
    organization = Organization.create!(name: "Org ZC Create")

    connection = ZabbixConnections::Create.new(
      organization:,
      payload: { name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local" }
    ).call

    assert connection.persisted?
    assert_equal organization.id, connection.organization_id
  end
end
