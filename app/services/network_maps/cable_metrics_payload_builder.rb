class NetworkMaps::CableMetricsPayloadBuilder
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
                         .includes(network_cable_items: { zabbix_item: :zabbix_connection })
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

    {
      id: cable.id,
      external_id: cable.external_id,
      label: cable.label,
      status: cable.status,
      zabbix_status: zabbix_status,
      operational_state: operational[:operational_state],
      traffic_level: operational[:traffic_level],
      alert_level: operational[:alert_level],
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

  def derive_zabbix_status(cable)
    status_item = cable.network_cable_items.find { |ci| ci.metric_role == "status" }
    return "unknown" unless status_item&.zabbix_item

    zi    = status_item.zabbix_item
    live  = (@live_values || {})[zi.itemid.to_s]
    value = (live&.dig("value") || zi.lastvalue).to_s.strip.downcase
    return "unknown" if value.blank?

    # ifOperStatus: 1=up, 2=down, 3=testing, 4=unknown, 5=dormant, 6=notPresent, 7=lowerLayerDown.
    return "up" if %w[1 up].include?(value)
    return "down" if %w[2 down].include?(value)
    return "degraded" if %w[3 5 7 testing dormant lowerlayerdown lower_layer_down].include?(value)
    return "unknown" if %w[4 6 unknown notpresent not_present unavailable].include?(value)

    "unknown"
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
