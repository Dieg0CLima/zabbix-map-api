require "test_helper"

class Zabbix::Observability::FetchMetricsTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Obs Org Metrics")
    @connection = @organization.zabbix_connections.create!(name: "Primary", status: "active", connection_mode: "api", base_url: "https://zabbix.example", api_token: "token")
    @device = @organization.devices.create!(name: "SW-01", role: "switch", status: "active")
    @device.zabbix_links.create!(organization: @organization, zabbix_connection: @connection, resource_type: "host", external_id: "20202", name: "SW-01")
  end

  test "builds normalized traffic cpu and memory payload" do
    client = Minitest::Mock.new
    client.expect(:call, [
      { "itemid" => "1", "name" => "Inbound traffic on eth0", "key_" => 'net.if.in["eth0"]', "lastvalue" => "15375", "lastclock" => "1710879300", "units" => "B", "tags" => [] },
      { "itemid" => "2", "name" => "Outbound traffic on eth0", "key_" => 'net.if.out["eth0"]', "lastvalue" => "12250", "lastclock" => "1710879300", "units" => "B", "tags" => [] },
      { "itemid" => "3", "name" => "CPU utilization", "key_" => "system.cpu.util[,system,avg1]", "lastvalue" => "72.4", "lastclock" => "1710879300", "units" => "%", "tags" => [] },
      { "itemid" => "4", "name" => "Memory utilization", "key_" => "vm.memory.size[pused]", "lastvalue" => "65.1", "lastclock" => "1710879300", "units" => "%", "tags" => [] }
    ], ["item.get", Hash])

    service = Zabbix::Observability::FetchMetrics.new(device: @device, client_class: ->(connection:) { client }, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute))
    payload = service.call

    assert_equal 1, payload[:traffic].size
    assert_equal "eth0", payload[:traffic].first[:interface]
    assert_equal 123000, payload[:traffic].first[:in_bps]
    assert_equal 98000, payload[:traffic].first[:out_bps]
    assert_equal 72, payload[:cpu][:usage]
    assert_equal 65, payload[:memory][:usage]
    client.verify
  end

  test "supports broader zabbix keys in database mode without requiring tags" do
    @connection.update!(connection_mode: "database", db_adapter: "postgresql", db_host: "127.0.0.1", db_port: 5432, db_name: "zabbix", db_username: "zabbix", db_password: "secret", base_url: nil)

    db_fetcher = Minitest::Mock.new
    db_fetcher.expect(:call, [
      { itemid: "1", name: "Incoming traffic on xe-0/0/0", key_: 'net.if.in[ifHCInOctets.1]', lastvalue: "1000", lastclock: Time.zone.at(1_710_879_300), units: "B", value_type: "3", description: nil, tags: [] },
      { itemid: "2", name: "Outgoing traffic on xe-0/0/0", key_: 'net.if.out[ifHCOutOctets.1]', lastvalue: "500", lastclock: Time.zone.at(1_710_879_300), units: "B", value_type: "3", description: nil, tags: [] },
      { itemid: "3", name: "Processor load", key_: 'system.cpu.util[,idle]', lastvalue: "31.2", lastclock: Time.zone.at(1_710_879_300), units: "%", value_type: "0", description: nil, tags: [] },
      { itemid: "4", name: "Memory usage", key_: 'vm.memory.util', lastvalue: "64.6", lastclock: Time.zone.at(1_710_879_300), units: "%", value_type: "0", description: nil, tags: [] }
    ])

    Zabbix::DatabaseItemsFetcher.stub(:new, db_fetcher) do
      payload = Zabbix::Observability::FetchMetrics.new(device: @device, cache: Zabbix::Observability::Cache.new(store: ActiveSupport::Cache::MemoryStore.new, ttl: 1.minute)).call
      assert_equal 1, payload[:traffic].size
      assert_equal 8000, payload[:traffic].first[:in_bps]
      assert_equal 4000, payload[:traffic].first[:out_bps]
      assert_equal 31, payload[:cpu][:usage]
      assert_equal 65, payload[:memory][:usage]
      assert_equal false, payload[:zabbix_unavailable]
    end

    db_fetcher.verify
  end
end
