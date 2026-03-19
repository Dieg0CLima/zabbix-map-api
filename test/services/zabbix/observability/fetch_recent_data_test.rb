require "test_helper"

class Zabbix::Observability::FetchRecentDataTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Obs Org Recent")
    @connection = @organization.zabbix_connections.create!(name: "Primary", status: "active", connection_mode: "api", base_url: "https://zabbix.example", api_token: "token")
    @device = @organization.devices.create!(name: "RTR-RECENT", role: "router", status: "active")
    @device.zabbix_links.create!(organization: @organization, zabbix_connection: @connection, resource_type: "host", external_id: "50505", name: "RTR-RECENT")
  end

  test "returns normalized recent host data for frontend" do
    now = Time.utc(2026, 3, 19, 12, 0, 0)

    Time.stub(:current, now) do
      client = Minitest::Mock.new
      client.expect(:call, [
        {
          "itemid" => "9001",
          "name" => "Latência",
          "key_" => "icmppingsec",
          "lastvalue" => "12.67",
          "prevvalue" => "12.64",
          "lastclock" => (now.to_i - 13).to_s,
          "units" => "ms",
          "value_type" => "0",
          "description" => "Ping do host",
          "state" => "0",
          "status" => "0",
          "tags" => [{ "tag" => "Application", "value" => "ICMP" }]
        },
        {
          "itemid" => "9002",
          "name" => "Status",
          "key_" => "icmpping",
          "lastvalue" => "Online (1)",
          "prevvalue" => "Online (1)",
          "lastclock" => (now.to_i - 13).to_s,
          "units" => "",
          "value_type" => "4",
          "description" => nil,
          "state" => "0",
          "status" => "0",
          "tags" => [{ "tag" => "Application", "value" => "ICMP" }]
        }
      ], ["item.get", Hash])

      service = Zabbix::Observability::FetchRecentData.new(device: @device, client_class: ->(connection:) { client }, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute))
      payload = service.call

      assert_equal "50505", payload.dig(:host, :id)
      assert_equal 2, payload[:items].size
      assert_equal "Latência", payload[:items].first[:name]
      assert_equal 13, payload[:items].first[:last_check_ago_seconds]
      assert_equal "12.67ms", payload[:items].first[:last_value]
      assert_equal "12.64ms", payload[:items].first[:previous_value]
      assert_equal "ICMP", payload[:items].first[:applications].first
      assert_equal "text", payload[:items].last[:value_type]
      assert_nil payload[:items].last[:change]
      client.verify
    end
  end
end
