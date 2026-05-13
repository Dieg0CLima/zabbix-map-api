class NetworkMaps::CableMetricsPayloadBuilder
  TELEMETRY_METRIC_ROLES = %w[
    bandwidth_in
    bandwidth_out
    error_in
    error_out
    crc_in
    crc_out
  ].freeze

  IF_OPER_STATUS_MAP = {
    1 => "up",
    2 => "down",
    3 => "degraded",
    4 => "unknown",
    5 => "degraded",
    6 => "unknown",
    7 => "degraded"
  }.freeze

  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id: @network_map.id,
      cables: cable_metrics
    }
  end

  private

  def cable_metrics
    cables = @network_map.network_cables
                         .includes(
                           { cable_fusion_diagram: :links },
                           :source_node,
                           :target_node,
                           { source_node: :zabbix_host },
                           { target_node: :zabbix_host },
                           { network_cable_items: { zabbix_item: :zabbix_connection } }
                         )
                         .order(:id)

    all_zabbix_items = cables.flat_map { |c| c.network_cable_items.filter_map(&:zabbix_item) }
    @live_values = Zabbix::LiveValuesFetcher.new(items: all_zabbix_items).call

    cables.map { |cable| build_cable_metrics(cable) }
  end

  def build_cable_metrics(cable)
    zabbix_status = derive_zabbix_status(cable)
    operational = NetworkCables::OperationalStateBuilder.new(
      cable: cable,
      live_values: @live_values,
      zabbix_status: zabbix_status
    ).call
    visual = NetworkCables::OperationalVisualProfile.new(
      cable_status: cable.status,
      zabbix_status: zabbix_status,
      operational_state: operational[:operational_state],
      traffic_level: operational[:traffic_level],
      alert_level: operational[:alert_level]
    ).call
    fusion_metrics = fusion_metrics_for(cable)

    {
      id: cable.id,
      external_id: cable.external_id,
      label: cable.label,
      status: cable.status,
      zabbix_status: zabbix_status,
      operational_state: operational[:operational_state],
      traffic_level: operational[:traffic_level],
      alert_level: operational[:alert_level],
      fusion_state: fusion_metrics[:fusion_state],
      fusion_occupancy_percent: fusion_metrics[:fusion_occupancy_percent],
      fusion_alerts_count: fusion_metrics[:fusion_alerts_count],
      fusion_published_version: fusion_metrics[:fusion_published_version],
      visual: visual,
      operational_details: {
        upload_bps: operational[:upload_bps],
        download_bps: operational[:download_bps],
        upload_utilization_pct: operational[:upload_utilization_pct],
        download_utilization_pct: operational[:download_utilization_pct],
        max_utilization_pct: operational[:max_utilization_pct],
        capacity_mbps: operational[:capacity_mbps],
        error_in: operational[:error_in],
        error_out: operational[:error_out],
        crc_in: operational[:crc_in],
        crc_out: operational[:crc_out],
        lastclock: operational[:lastclock],
        thresholds: operational[:thresholds]
      },
      items: cable.network_cable_items.map { |ci| build_item(ci) }
    }
  end

  def fusion_metrics_for(cable)
    diagram = cable.cable_fusion_diagram
    return { fusion_state: "draft", fusion_occupancy_percent: 0.0, fusion_alerts_count: 0, fusion_published_version: 0 } unless diagram

    links_with_fiber = diagram.links.where.not(fiber_side: [ nil, "" ]).where.not(fiber_number: nil).count
    fiber_count = cable.metadata.to_h["fiber_count"].to_i
    occupancy_percent = if fiber_count.positive?
      ((links_with_fiber.to_f / fiber_count) * 100.0).round(2)
    else
      0.0
    end

    {
      fusion_state: diagram.status,
      fusion_occupancy_percent: occupancy_percent,
      fusion_alerts_count: diagram.validation_errors_count.to_i,
      fusion_published_version: diagram.version.to_i
    }
  end

  def derive_zabbix_status(cable)
    endpoint_status = endpoint_zabbix_status(cable)

    status_item = cable.network_cable_items.find { |ci| ci.metric_role == "status" }
    return telemetry_presence_status(cable) || endpoint_status unless status_item&.zabbix_item

    zi    = status_item.zabbix_item
    live  = (@live_values || {})[zi.itemid.to_s]
    raw_value = live&.dig("value") || zi.lastvalue
    value = raw_value.to_s.strip.downcase
    return telemetry_presence_status(cable) || endpoint_status if value.blank?

    code = parse_if_oper_status_code(value)
    if code
      mapped = IF_OPER_STATUS_MAP.fetch(code)
      return mapped unless mapped == "unknown"
    end

    return "up" if value.match?(/\bup\b/)
    return "down" if value.match?(/\bdown\b/)
    return "degraded" if value.in?(%w[testing dormant lowerlayerdown lower_layer_down])
    if value.in?(%w[unknown notpresent not_present unavailable])
      return telemetry_presence_status(cable) || endpoint_status
    end

    telemetry_presence_status(cable) || endpoint_status
  end

  def parse_if_oper_status_code(value)
    numeric = Float(value)
    return nil unless numeric.finite?

    code = numeric.to_i
    return nil unless numeric == code
    return nil unless IF_OPER_STATUS_MAP.key?(code)

    code
  rescue ArgumentError, TypeError
    if (match = value.match(/\A(\d+)/))
      code = match[1].to_i
      return code if IF_OPER_STATUS_MAP.key?(code)
    end

    nil
  end

  def endpoint_zabbix_status(cable)
    statuses = [ cable.source_node, cable.target_node ]
               .compact
               .map { |node| host_status_label(node.zabbix_host) }
               .compact

    return "unknown" if statuses.empty?
    return "down" if statuses.include?("down")
    return "degraded" if statuses.include?("degraded")
    return "up" if statuses.include?("up")

    "unknown"
  end

  def telemetry_presence_status(cable)
    telemetry_items = cable.network_cable_items.select do |cable_item|
      cable_item.zabbix_item_id.present? && TELEMETRY_METRIC_ROLES.include?(cable_item.metric_role)
    end
    return nil if telemetry_items.empty?

    has_signal = telemetry_items.any? do |cable_item|
      zabbix_item = cable_item.zabbix_item
      next false unless zabbix_item

      live = (@live_values || {})[zabbix_item.itemid.to_s]
      value = live&.dig("value") || zabbix_item.lastvalue
      clock = live&.dig("clock") || zabbix_item.lastclock
      value.to_s.strip.present? || clock.to_s.strip.present?
    end

    has_signal ? "up" : nil
  end

  def host_status_label(host)
    return nil unless host
    return "down" if host.status.to_s == "1" || host.status.to_s.casecmp("disabled").zero?

    host_available?(host) ? "up" : "degraded"
  end

  def host_available?(host)
    value = host.available
    return value if value == true || value == false

    value.to_s.strip.downcase.in?(%w[1 true up available enabled])
  end

  def build_item(cable_item)
    zabbix_item = cable_item.zabbix_item
    live        = zabbix_item ? (@live_values || {})[zabbix_item.itemid.to_s] : nil

    {
      id:               cable_item.id,
      network_cable_id: cable_item.network_cable_id,
      zabbix_item_id:   cable_item.zabbix_item_id,
      alias:            cable_item.alias,
      metric_role:      cable_item.metric_role,
      display_order:    cable_item.display_order,
      itemid:           zabbix_item&.itemid,
      name:             zabbix_item&.name,
      key_:             zabbix_item&.key_,
      units:            zabbix_item&.units,
      lastvalue:        live&.dig("value") || zabbix_item&.lastvalue,
      lastclock:        live&.dig("clock")&.to_s || zabbix_item&.lastclock&.to_s
    }
  end
end
