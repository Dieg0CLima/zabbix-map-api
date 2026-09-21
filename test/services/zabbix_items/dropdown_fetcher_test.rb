require "test_helper"

class ZabbixItems::DropdownFetcherTest < ActiveSupport::TestCase
  test "returns dropdown items ordered by name and filtered by host when provided" do
    organization = Organization.create!(name: "Org Zabbix Items Dropdown")
    connection = organization.zabbix_connections.create!(name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local")
    host_a = connection.zabbix_hosts.create!(hostid: "101", name: "OLT-1")
    host_b = connection.zabbix_hosts.create!(hostid: "102", name: "OLT-2")

    connection.zabbix_items.create!(itemid: "1", name: "CPU", key_: "system.cpu", value_type: 3, units: "%", zabbix_host: host_a)
    connection.zabbix_items.create!(itemid: "2", name: "RAM", key_: "vm.memory", value_type: 3, units: "MB", zabbix_host: host_b)

    result = ZabbixItems::DropdownFetcher.new(connection: connection, zabbix_host_id: host_a.id).call

    assert_equal 1, result.items.size
    assert_equal connection.id, result.meta[:connection_id]
    assert_equal 1, result.meta[:count]
    assert_equal "CPU (system.cpu)", result.items.first[:label]
    assert_equal "1", result.items.first[:itemid]
    assert_equal "%", result.items.first[:units]
    assert_equal "3", result.items.first[:value_type]
  end
end
