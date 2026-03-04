require "test_helper"

class ZabbixItems::FetchTest < ActiveSupport::TestCase
  test "filters persisted items by zabbix_host_id when db mode disabled" do
    organization = Organization.create!(name: "Org ZI Fetch")
    connection = organization.zabbix_connections.create!(name: "Conn", status: "active", connection_mode: "api", base_url: "https://zabbix.local")
    host_a = connection.zabbix_hosts.create!(hostid: "101", name: "OLT-1")
    host_b = connection.zabbix_hosts.create!(hostid: "102", name: "OLT-2")
    connection.zabbix_items.create!(itemid: "1", name: "CPU", key_: "system.cpu", value_type: 3, zabbix_host: host_a)
    connection.zabbix_items.create!(itemid: "2", name: "RAM", key_: "vm.memory", value_type: 3, zabbix_host: host_b)

    items = ZabbixItems::Fetch.new(connection:, hostid: nil, zabbix_host_id: host_a.id, limit: nil).call

    assert_equal 1, items.count
    assert_equal "CPU", items.first.name
  end
end
