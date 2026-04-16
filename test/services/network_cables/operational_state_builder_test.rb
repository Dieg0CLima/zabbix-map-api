require "test_helper"

class NetworkCables::OperationalStateBuilderTest < ActiveSupport::TestCase
  Cable = Struct.new(:network_cable_items, :bandwidth_mbps, :metadata, keyword_init: true)
  CableItem = Struct.new(:metric_role, :zabbix_item, keyword_init: true)
  ZabbixItem = Struct.new(:itemid, :lastvalue, :lastclock, keyword_init: true)

  test "classifies port_down when zabbix_status is down" do
    cable = build_cable(
      roles: {
        "bandwidth_in" => "12500000",
        "bandwidth_out" => "25000000"
      },
      bandwidth_mbps: 100
    )

    payload = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: {},
      zabbix_status: "down"
    ).call

    assert_equal "port_down", payload[:operational_state]
    assert_equal "critical", payload[:alert_level]
  end

  test "classifies saturation when utilization is above high threshold" do
    cable = build_cable(
      roles: {
        "bandwidth_in" => "98000000",
        "bandwidth_out" => "1000000"
      },
      bandwidth_mbps: 100
    )

    payload = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: {},
      zabbix_status: "up"
    ).call

    assert_equal "saturation", payload[:operational_state]
    assert_equal "saturated", payload[:traffic_level]
    assert_equal 98.0, payload[:max_utilization_pct]
  end

  test "classifies physical_alert when crc metric is positive" do
    cable = build_cable(
      roles: {
        "bandwidth_in" => "1000000",
        "bandwidth_out" => "1000000",
        "crc_in" => "5"
      },
      bandwidth_mbps: 100
    )

    payload = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: {},
      zabbix_status: "up"
    ).call

    assert_equal "physical_alert", payload[:operational_state]
    assert_equal "critical", payload[:alert_level]
    assert_equal 5.0, payload[:crc_in]
  end

  test "classifies traffic_low when cable has traffic but no capacity configured" do
    cable = build_cable(
      roles: {
        "bandwidth_in" => "985349384"
      },
      bandwidth_mbps: nil
    )

    payload = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: {},
      zabbix_status: nil
    ).call

    assert_equal "traffic_low", payload[:operational_state]
    assert_equal "low", payload[:traffic_level]
    assert_equal "ok", payload[:alert_level]
  end

  test "sums multiple bandwidth items for the same role" do
    cable = build_cable(
      roles: [
        [ "bandwidth_in", "100000000" ],
        [ "bandwidth_in", "250000000" ],
        [ "bandwidth_out", "50000000" ]
      ],
      bandwidth_mbps: 1000
    )

    payload = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: {},
      zabbix_status: "up"
    ).call

    assert_equal 350_000_000.0, payload[:download_bps]
    assert_equal 50_000_000.0, payload[:upload_bps]
    assert_equal 35.0, payload[:download_utilization_pct]
    assert_equal 5.0, payload[:upload_utilization_pct]
    assert_equal 35.0, payload[:max_utilization_pct]
  end

  private

  def build_cable(roles:, bandwidth_mbps:, metadata: {})
    normalized_roles = roles.is_a?(Hash) ? roles.to_a : Array(roles)

    items = normalized_roles.map.with_index do |(role, value), index|
      zabbix_item = ZabbixItem.new(
        itemid: (index + 1).to_s,
        lastvalue: value,
        lastclock: Time.current
      )

      CableItem.new(metric_role: role, zabbix_item: zabbix_item)
    end

    Cable.new(network_cable_items: items, bandwidth_mbps: bandwidth_mbps, metadata: metadata)
  end
end
