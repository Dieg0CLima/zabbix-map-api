require "test_helper"

class Zabbix::Observability::FetchEventsTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Obs Org Events")
    @connection = @organization.zabbix_connections.create!(name: "Primary", status: "active", connection_mode: "api", base_url: "https://zabbix.example", api_token: "token")
    @device = @organization.devices.create!(name: "RTR-01", role: "router", status: "active")
    @device.zabbix_links.create!(organization: @organization, zabbix_connection: @connection, resource_type: "host", external_id: "10101", name: "RTR-01")
  end

  test "returns active problems with normalized severity and duration" do
    now = Time.utc(2026, 3, 19, 12, 0, 0)
    Time.stub(:current, now) do
      client = Minitest::Mock.new
      client.expect(:call, [
        {
          "eventid" => "12345",
          "name" => "High CPU usage",
          "severity" => "4",
          "clock" => (now.to_i - 320).to_s,
          "acknowledged" => "0",
          "value" => "1",
          "r_eventid" => "0"
        },
        {
          "eventid" => "12346",
          "name" => "Resolved",
          "severity" => "2",
          "clock" => (now.to_i - 10).to_s,
          "acknowledged" => "1",
          "value" => "0",
          "r_eventid" => "888"
        }
      ], ["problem.get", Hash])

      service = Zabbix::Observability::FetchEvents.new(device: @device, client_class: ->(connection:) { client }, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute))
      payload = service.call

      assert_equal "problem", payload[:status]
      assert_equal 1, payload[:active_problems]
      assert_equal({ "high" => 1 }, payload[:severity_breakdown].transform_keys(&:to_s))
      assert_equal "12345", payload[:events].first[:id]
      assert_equal 320, payload[:events].first[:duration]
      assert_equal false, payload[:events].first[:acknowledged]
      assert_equal "high", payload[:events].first[:severity]
      client.verify
    end
  end
end
