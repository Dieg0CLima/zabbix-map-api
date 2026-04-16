require "test_helper"

class NetworkMaps::CableMetricsPayloadBuilderTest < ActiveSupport::TestCase
  test "adds operational_state and operational_details to cable metrics payload" do
    organization = Organization.create!(name: "Org Cable Metrics")
    connection = organization.zabbix_connections.create!(
      name: "Conn A",
      connection_mode: "api",
      status: "active",
      base_url: "https://zabbix.example.com"
    )
    network_map = organization.network_maps.create!(
      name: "Mapa Operacional",
      source_type: "manual",
      zabbix_connection: connection
    )
    source_pop = network_map.map_pops.create!(name: "POP 1", external_id: "pop-1", lat: -23.10, lng: -46.10, color: "#7c3aed")

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      label: "Backbone 10G",
      status: "active",
      bandwidth_mbps: 100,
      metadata: { "operational_thresholds" => { "low_pct" => 50, "moderate_pct" => 80, "high_pct" => 95 } }
    )

    status_item = connection.zabbix_items.create!(
      itemid: "101",
      name: "ifOperStatus",
      key_: "net.if.status[1]",
      units: "",
      lastvalue: "1",
      lastclock: Time.current
    )
    in_item = connection.zabbix_items.create!(
      itemid: "102",
      name: "ifInOctets",
      key_: "net.if.in[1]",
      units: "bps",
      lastvalue: "96000000",
      lastclock: Time.current
    )
    out_item = connection.zabbix_items.create!(
      itemid: "103",
      name: "ifOutOctets",
      key_: "net.if.out[1]",
      units: "bps",
      lastvalue: "12000000",
      lastclock: Time.current
    )

    cable.network_cable_items.create!(zabbix_item: status_item, metric_role: "status")
    cable.network_cable_items.create!(zabbix_item: in_item, metric_role: "bandwidth_in")
    cable.network_cable_items.create!(zabbix_item: out_item, metric_role: "bandwidth_out")

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].first

    assert_equal "up", cable_payload[:zabbix_status]
    assert_equal "saturation", cable_payload[:operational_state]
    assert_equal "critical", cable_payload[:alert_level]
    assert_equal "saturated", cable_payload[:traffic_level]
    assert_equal 96.0, cable_payload.dig(:operational_details, :max_utilization_pct)
    assert_equal 100, cable_payload.dig(:operational_details, :capacity_mbps)
  end
end
