require "test_helper"

class ZabbixConnections::UpdateTest < ActiveSupport::TestCase
  test "updates connection" do
    organization = Organization.create!(name: "Org ZC Update")
    connection = organization.zabbix_connections.create!(name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local")

    updated = ZabbixConnections::Update.new(connection:, payload: { status: "inactive" }).call

    assert_equal "inactive", updated.status
  end
end
