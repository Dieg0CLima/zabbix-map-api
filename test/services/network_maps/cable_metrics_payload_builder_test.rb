require "test_helper"

class NetworkMaps::CableMetricsPayloadBuilderTest < ActiveSupport::TestCase
  test "includes fusion metrics dimension separated from zabbix_status" do
    organization = Organization.create!(name: "Org Fusion Metrics")
    network_map = organization.network_maps.create!(name: "Mapa Fusion Metrics", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Fusion", external_id: "pop-fusion", lat: -23.10, lng: -46.10, color: "#7c3aed")
    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      label: "Cabo Fusion",
      status: "active",
      metadata: { "fiber_count" => 4 }
    )

    diagram = CableFusion::LoadDiagram.new(cable: cable).call
    diagram.update!(status: "invalid", version: 2, validation_errors_count: 3)
    node = diagram.nodes.create!(node_type: "dio", label: "DIO", x: 0, y: 0, rotation: 0)
    p1 = node.ports.create!(name: "P1", port_type: "fiber_in", capacity: 1, occupancy_limit: 2)
    p2 = node.ports.create!(name: "P2", port_type: "fiber_out", capacity: 1, occupancy_limit: 2)
    diagram.links.create!(source_port: p1, target_port: p2, link_kind: "splice", fiber_side: "a", fiber_number: 1, status: "draft")

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "unknown", cable_payload[:zabbix_status]
    assert_equal "invalid", cable_payload[:fusion_state]
    assert_equal 25.0, cable_payload[:fusion_occupancy_percent]
    assert_equal 3, cable_payload[:fusion_alerts_count]
    assert_equal 2, cable_payload[:fusion_published_version]
  end

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
    assert_equal "#dc2626", cable_payload.dig(:visual, :cable_color)
    assert_equal "#dc2626", cable_payload.dig(:visual, :indicator_color)
    assert_equal "danger", cable_payload.dig(:visual, :indicator_severity)
    assert_equal "Saturação", cable_payload.dig(:visual, :state_label)
  end

  test "maps ifOperStatus degraded values to degraded zabbix_status" do
    network_map, cable, _status_item = build_map_with_status_item(lastvalue: "7")

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "degraded", cable_payload[:zabbix_status]
  end

  test "maps decimal ifOperStatus values to up/down/degraded/unknown" do
    network_map_up, cable_up, _status_up = build_map_with_status_item(lastvalue: "1.0")
    network_map_down, cable_down, _status_down = build_map_with_status_item(lastvalue: "2.0")
    network_map_degraded, cable_degraded, _status_degraded = build_map_with_status_item(lastvalue: "7.0")
    network_map_unknown, cable_unknown, _status_unknown = build_map_with_status_item(lastvalue: "4.0")

    up_payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map_up).call
    down_payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map_down).call
    degraded_payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map_degraded).call
    unknown_payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map_unknown).call

    assert_equal "up", up_payload[:cables].find { |entry| entry[:id] == cable_up.id }[:zabbix_status]
    assert_equal "down", down_payload[:cables].find { |entry| entry[:id] == cable_down.id }[:zabbix_status]
    assert_equal "degraded", degraded_payload[:cables].find { |entry| entry[:id] == cable_degraded.id }[:zabbix_status]
    assert_equal "unknown", unknown_payload[:cables].find { |entry| entry[:id] == cable_unknown.id }[:zabbix_status]
  end

  test "maps ifOperStatus unknown values to unknown zabbix_status" do
    network_map, cable, _status_item = build_map_with_status_item(lastvalue: "not_present")

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "unknown", cable_payload[:zabbix_status]
    assert_equal "#059669", cable_payload.dig(:visual, :cable_color)
    assert_equal "#64748b", cable_payload.dig(:visual, :status_color)
  end

  test "returns unknown zabbix_status when cable has no status item" do
    organization = Organization.create!(name: "Org Cable No Status #{SecureRandom.hex(4)}")
    network_map = organization.network_maps.create!(
      name: "Mapa No Status #{SecureRandom.hex(3)}",
      source_type: "manual"
    )
    source_pop = network_map.map_pops.create!(
      name: "POP No Status",
      external_id: "pop-no-status-#{SecureRandom.hex(3)}",
      lat: -23.10,
      lng: -46.10,
      color: "#7c3aed"
    )

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      label: "Cabo sem status",
      status: "active"
    )

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "unknown", cable_payload[:zabbix_status]
  end

  test "falls back to endpoint host statuses when cable has no status item" do
    organization = Organization.create!(name: "Org Cable Host Fallback #{SecureRandom.hex(4)}")
    connection = organization.zabbix_connections.create!(
      name: "Conn Host Fallback #{SecureRandom.hex(3)}",
      connection_mode: "api",
      status: "active",
      base_url: "https://zabbix.example.com"
    )
    network_map = organization.network_maps.create!(
      name: "Mapa Host Fallback #{SecureRandom.hex(3)}",
      source_type: "manual",
      zabbix_connection: connection
    )
    source_pop = network_map.map_pops.create!(
      name: "POP Host Fallback",
      external_id: "pop-host-fallback-#{SecureRandom.hex(3)}",
      lat: -23.10,
      lng: -46.10,
      color: "#7c3aed"
    )

    host_up = connection.zabbix_hosts.create!(hostid: "host-up-#{SecureRandom.hex(4)}", name: "Host UP", status: "0", available: "1")
    host_degraded = connection.zabbix_hosts.create!(hostid: "host-degraded-#{SecureRandom.hex(4)}", name: "Host Degraded", status: "0", available: "0")

    source_node = network_map.map_nodes.create!(
      map_pop: source_pop,
      label: "Source Node",
      node_kind: "router",
      x: -23.10,
      y: -46.10,
      zabbix_host: host_up
    )
    target_node = network_map.map_nodes.create!(
      map_pop: source_pop,
      label: "Target Node",
      node_kind: "router",
      x: -23.11,
      y: -46.11,
      zabbix_host: host_degraded
    )

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      source_node: source_node,
      target_node: target_node,
      label: "Cabo sem item status",
      status: "active"
    )

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "degraded", cable_payload[:zabbix_status]
  end

  test "prioritizes down on endpoint fallback when any endpoint host is down" do
    organization = Organization.create!(name: "Org Cable Host Fallback Down #{SecureRandom.hex(4)}")
    connection = organization.zabbix_connections.create!(
      name: "Conn Host Fallback Down #{SecureRandom.hex(3)}",
      connection_mode: "api",
      status: "active",
      base_url: "https://zabbix.example.com"
    )
    network_map = organization.network_maps.create!(
      name: "Mapa Host Fallback Down #{SecureRandom.hex(3)}",
      source_type: "manual",
      zabbix_connection: connection
    )
    source_pop = network_map.map_pops.create!(
      name: "POP Host Fallback Down",
      external_id: "pop-host-fallback-down-#{SecureRandom.hex(3)}",
      lat: -23.10,
      lng: -46.10,
      color: "#7c3aed"
    )

    host_up = connection.zabbix_hosts.create!(hostid: "host-up-#{SecureRandom.hex(4)}", name: "Host UP", status: "0", available: "1")
    host_down = connection.zabbix_hosts.create!(hostid: "host-down-#{SecureRandom.hex(4)}", name: "Host Down", status: "1", available: "0")

    source_node = network_map.map_nodes.create!(
      map_pop: source_pop,
      label: "Source Node Down Fallback",
      node_kind: "router",
      x: -23.10,
      y: -46.10,
      zabbix_host: host_up
    )
    target_node = network_map.map_nodes.create!(
      map_pop: source_pop,
      label: "Target Node Down Fallback",
      node_kind: "router",
      x: -23.12,
      y: -46.12,
      zabbix_host: host_down
    )

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      source_node: source_node,
      target_node: target_node,
      label: "Cabo sem item status (down)",
      status: "active"
    )

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "down", cable_payload[:zabbix_status]
  end

  test "falls back to up when telemetry items have signal and no status item" do
    organization = Organization.create!(name: "Org Cable Telemetry Fallback #{SecureRandom.hex(4)}")
    connection = organization.zabbix_connections.create!(
      name: "Conn Telemetry Fallback #{SecureRandom.hex(3)}",
      connection_mode: "api",
      status: "active",
      base_url: "https://zabbix.example.com"
    )
    network_map = organization.network_maps.create!(
      name: "Mapa Telemetry Fallback #{SecureRandom.hex(3)}",
      source_type: "manual",
      zabbix_connection: connection
    )
    source_pop = network_map.map_pops.create!(
      name: "POP Telemetry Fallback",
      external_id: "pop-telemetry-fallback-#{SecureRandom.hex(3)}",
      lat: -23.10,
      lng: -46.10,
      color: "#7c3aed"
    )

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      label: "Cabo sem status mas com telemetria",
      status: "active"
    )

    in_item = connection.zabbix_items.create!(
      itemid: "telemetry-in-#{SecureRandom.hex(4)}",
      name: "ifInOctets",
      key_: "net.if.in[1]",
      units: "bps",
      lastvalue: "12500000",
      lastclock: Time.current
    )
    out_item = connection.zabbix_items.create!(
      itemid: "telemetry-out-#{SecureRandom.hex(4)}",
      name: "ifOutOctets",
      key_: "net.if.out[1]",
      units: "bps",
      lastvalue: "8300000",
      lastclock: Time.current
    )

    cable.network_cable_items.create!(zabbix_item: in_item, metric_role: "bandwidth_in")
    cable.network_cable_items.create!(zabbix_item: out_item, metric_role: "bandwidth_out")

    payload = NetworkMaps::CableMetricsPayloadBuilder.new(network_map: network_map).call
    cable_payload = payload[:cables].find { |entry| entry[:id] == cable.id }

    assert_equal "up", cable_payload[:zabbix_status]
  end

  private

  def build_map_with_status_item(lastvalue:)
    organization = Organization.create!(name: "Org Cable Status #{SecureRandom.hex(4)}")
    connection = organization.zabbix_connections.create!(
      name: "Conn Status #{SecureRandom.hex(3)}",
      connection_mode: "api",
      status: "active",
      base_url: "https://zabbix.example.com"
    )
    network_map = organization.network_maps.create!(
      name: "Mapa Status #{SecureRandom.hex(3)}",
      source_type: "manual",
      zabbix_connection: connection
    )
    source_pop = network_map.map_pops.create!(
      name: "POP Status",
      external_id: "pop-status-#{SecureRandom.hex(3)}",
      lat: -23.10,
      lng: -46.10,
      color: "#7c3aed"
    )

    cable = network_map.network_cables.create!(
      source_pop: source_pop,
      label: "Cabo Status",
      status: "active",
      bandwidth_mbps: 100
    )

    status_item = connection.zabbix_items.create!(
      itemid: "status-#{SecureRandom.hex(4)}",
      name: "ifOperStatus",
      key_: "net.if.status[1]",
      units: "",
      lastvalue: lastvalue,
      lastclock: Time.current
    )

    cable.network_cable_items.create!(zabbix_item: status_item, metric_role: "status")
    [ network_map, cable, status_item ]
  end
end
