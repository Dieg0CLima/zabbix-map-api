require "test_helper"

class Zabbix::Observability::DatabasePreferenceTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Obs Org DB Pref")
    @connection = @organization.zabbix_connections.create!(
      name: "Primary",
      status: "active",
      connection_mode: "database",
      db_adapter: "postgresql",
      db_host: "127.0.0.1",
      db_port: 5432,
      db_name: "zabbix",
      db_username: "zabbix",
      db_password: "secret"
    )
    @device = @organization.devices.create!(name: "RTR-DB", role: "router", status: "active")
    @device.zabbix_links.create!(organization: @organization, zabbix_connection: @connection, resource_type: "host", external_id: "60606", name: "RTR-DB")
  end

  test "recent data prefers database fetcher when db mode is enabled" do
    db_fetcher = Minitest::Mock.new
    db_fetcher.expect(:call, [
      {
        itemid: "1",
        name: "Latência",
        key_: "icmppingsec",
        value_type: "0",
        units: "ms",
        status: "0",
        state: "0",
        lastvalue: "10.2",
        prevvalue: "10.0",
        lastclock: Time.zone.at(1_700_000_000),
        description: "Ping",
        tags: [{ tag: "Application", value: "ICMP" }],
        host: { hostid: "60606", name: "RTR-DB" }
      }
    ])

    Zabbix::DatabaseItemsFetcher.stub(:new, db_fetcher) do
      payload = Zabbix::Observability::FetchRecentData.new(device: @device, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute)).call
      assert_equal "Latência", payload[:items].first[:name]
      assert_equal "ICMP", payload[:items].first[:applications].first
    end

    db_fetcher.verify
  end

  test "events prefer database fetcher when db mode is enabled" do
    db_fetcher = Minitest::Mock.new
    db_fetcher.expect(:call, [{ "eventid" => "7001", "name" => "Host down", "severity" => "4", "clock" => "1700000000", "acknowledged" => "0", "value" => "1", "r_eventid" => "0" }])

    Zabbix::DatabaseProblemsFetcher.stub(:new, db_fetcher) do
      payload = Zabbix::Observability::FetchEvents.new(device: @device, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute)).call
      assert_equal 1, payload[:active_problems]
      assert_equal "problem", payload[:status]
    end

    db_fetcher.verify
  end
end
