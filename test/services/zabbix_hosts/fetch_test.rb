require "test_helper"

class ZabbixHosts::FetchTest < ActiveSupport::TestCase
  test "returns persisted hosts when db mode disabled" do
    organization = Organization.create!(name: "Org ZH Fetch")
    connection = organization.zabbix_connections.create!(name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local")
    connection.zabbix_hosts.create!(hostid: "101", name: "OLT-1")

    hosts = ZabbixHosts::Fetch.new(connection:, limit: nil).call

    assert_equal 1, hosts.count
    assert_equal "OLT-1", hosts.first.name
  end
end
