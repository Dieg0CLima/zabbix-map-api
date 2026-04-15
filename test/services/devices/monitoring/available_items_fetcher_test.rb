require "test_helper"

class Devices::Monitoring::AvailableItemsFetcherTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Org Items", slug: "org-items-#{SecureRandom.hex(4)}")
    @connection = @organization.zabbix_connections.create!(
      name: "Items Connector",
      status: "active",
      connection_mode: "api",
      base_url: "https://z.example",
      api_token: SecureRandom.hex(16)
    )
    @device = @organization.devices.create!(
      name: "Edge Device",
      role: "router",
      status: "active"
    )
    @host_link = ZabbixLink.create!(
      organization: @organization,
      zabbix_connection: @connection,
      linkable: @device,
      resource_type: "host",
      external_id: "host-42",
      name: "Host 42",
      metadata: { hostid: "host-42" }
    )
    @profile = Devices::MonitoringProfileSync.new(device: @device).call
  end

  test "returns empty catalog when profile missing" do
    result = Devices::Monitoring::AvailableItemsFetcher.new(profile: nil).call

    assert_empty result[:items]
    assert_equal 0, result[:meta][:count]
    assert_nil result[:meta][:source]
  end

  test "builds items with classification hints and metadata" do
    raw_items = [
      { itemid: "100", name: "CPU load", key: "system.cpu.load", units: "%", value_type: "3", value: 1 },
      { itemid: "200", name: "Interface Traffic", key: "net.if.in", units: "bps", value_type: "3", value: 2 }
    ]

    fetcher_stub = Object.new
    fetcher_stub.define_singleton_method(:call) { raw_items }

    ZabbixHosts::ItemsFetcher.stub(:new, ->(**_) { fetcher_stub }) do
      result = Devices::Monitoring::AvailableItemsFetcher.new(profile: @profile, limit: 5).call

      assert_equal 2, result[:items].size
      cpu_item = result[:items].find { |item| item[:item_id] == "100" }
      assert_equal "cpu", cpu_item[:category_hint]
      assert_equal "CPU load", cpu_item[:suggested_alias]
      assert_equal "%", cpu_item[:units]
      assert_equal 1, cpu_item[:zabbix_item_id]
      assert_equal({}, cpu_item[:metadata])

      meta = result[:meta]
      assert_equal "host-42", meta[:hostid]
      assert_equal "upserted", meta[:source]
      assert_equal 2, meta[:count]
    end
  end

  test "handles fetcher errors gracefully" do
    raising_stub = Object.new
    raising_stub.define_singleton_method(:call) { raise ZabbixHosts::ItemsFetcher::Error, "boom" }

    ZabbixHosts::ItemsFetcher.stub(:new, ->(**_) { raising_stub }) do
      result = Devices::Monitoring::AvailableItemsFetcher.new(profile: @profile).call

      assert_empty result[:items]
      assert_equal 0, result[:meta][:count]
      assert_equal "host-42", result[:meta][:hostid]
    end
  end
end
