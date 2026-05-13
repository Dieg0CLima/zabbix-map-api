require "test_helper"

class ZabbixConnections::HostDropdownFetcherTest < ActiveSupport::TestCase
  test "returns persisted hosts as dropdown in API mode" do
    organization = Organization.create!(name: "Org Dropdown API")
    connection = organization.zabbix_connections.create!(
      name: "Conn API",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )

    connection.zabbix_hosts.create!(hostid: "10105", name: "OLT-POP-CENTRO", status: "0", available: "1")
    connection.zabbix_hosts.create!(hostid: "10106", name: "router-borda", status: "0", available: "0")

    result = ZabbixConnections::HostDropdownFetcher.new(connection: connection).call

    assert_equal 2, result.size
    assert_equal "OLT-POP-CENTRO", result.first[:label]
    assert_equal "10105", result.first[:value]
    assert_equal true, result.first[:available]
    assert_equal false, result.last[:available]
  end

  test "filters persisted hosts by query" do
    organization = Organization.create!(name: "Org Dropdown API Search")
    connection = organization.zabbix_connections.create!(
      name: "Conn API Search",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )

    connection.zabbix_hosts.create!(hostid: "10634", name: "SWCX-001-001-005-CENTRAL", status: "0", available: "1")
    connection.zabbix_hosts.create!(hostid: "10106", name: "MikroTik RB260GS by SNMP", status: "0", available: "1")

    result = ZabbixConnections::HostDropdownFetcher.new(connection: connection, query: "SWCX").call

    assert_equal 1, result.size
    assert_equal "SWCX-001-001-005-CENTRAL", result.first[:label]
  end

  test "excludes hosts with status 3 from persisted dropdown" do
    organization = Organization.create!(name: "Org Dropdown Persisted Status Filter")
    connection = organization.zabbix_connections.create!(
      name: "Conn API Status Filter",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )

    connection.zabbix_hosts.create!(hostid: "10100", name: "HOST-ENABLED", status: "0", available: "1")
    connection.zabbix_hosts.create!(hostid: "10101", name: "HOST-HIDDEN", status: "3", available: "1")

    result = ZabbixConnections::HostDropdownFetcher.new(connection: connection).call

    assert_equal [ "HOST-ENABLED" ], result.map { |row| row[:label] }
  end

  test "returns hosts from database fetcher in database mode" do
    organization = Organization.create!(name: "Org Dropdown DB")
    connection = organization.zabbix_connections.create!(
      name: "Conn DB",
      status: "active",
      connection_mode: "database",
      db_adapter: "postgresql",
      db_host: "localhost",
      db_port: 5432,
      db_name: "zabbix",
      db_username: "zabbix"
    )

    mock_fetcher = Minitest::Mock.new
    mock_fetcher.expect(:call, [
      { hostid: "30", name: "Template-Should-Hide", host: "template-hide", status: "3" },
      { hostid: "20", name: "Switch-1", host: "switch-1", status: "1" },
      { hostid: "10", name: "Router-1", host: "router-1", status: "0" }
    ])

    fetcher_factory = ->(**_kwargs) { mock_fetcher }
    Zabbix::DatabaseHostsFetcher.stub(:new, fetcher_factory) do
      result = ZabbixConnections::HostDropdownFetcher.new(connection: connection, limit: 50, query: "Router").call

      assert_equal [ "Router-1", "Switch-1" ], result.map { |row| row[:label] }
      assert_equal false, result.first[:available]
      assert_equal false, result.last[:available]
    end

    mock_fetcher.verify
  end
end
