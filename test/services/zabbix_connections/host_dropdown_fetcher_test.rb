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

    connection.zabbix_hosts.create!(hostid: "10105", name: "OLT-POP-CENTRO", available: "1")
    connection.zabbix_hosts.create!(hostid: "10106", name: "router-borda", available: "0")

    result = ZabbixConnections::HostDropdownFetcher.new(connection: connection).call

    assert_equal 2, result.size
    assert_equal "OLT-POP-CENTRO", result.first[:label]
    assert_equal "10105", result.first[:value]
    assert_equal true, result.first[:available]
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
      { hostid: "20", name: "Switch-1", host: "switch-1", status: "0" },
      { hostid: "10", name: "Router-1", host: "router-1", status: "1" }
    ])

    Zabbix::DatabaseHostsFetcher.stub(:new, mock_fetcher) do
      result = ZabbixConnections::HostDropdownFetcher.new(connection: connection, limit: 50).call

      assert_equal ["Router-1", "Switch-1"], result.map { |row| row[:label] }
      assert_equal false, result.first[:available]
      assert_equal true, result.last[:available]
    end

    mock_fetcher.verify
  end
end
