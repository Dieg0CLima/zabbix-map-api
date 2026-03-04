require "test_helper"

class ZabbixConnections::DestroyTest < ActiveSupport::TestCase
  test "destroys connection" do
    organization = Organization.create!(name: "Org ZC Destroy")
    connection = organization.zabbix_connections.create!(name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local")

    ZabbixConnections::Destroy.new(connection:).call

    assert_not ZabbixConnection.exists?(connection.id)
  end
end
