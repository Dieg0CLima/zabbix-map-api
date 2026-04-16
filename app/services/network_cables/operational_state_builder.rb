class NetworkCables::OperationalStateBuilder
  DEFAULT_THRESHOLDS = {
    low_pct: 50.0,
    moderate_pct: 80.0,
    high_pct: 95.0
  }.freeze

  def initialize(cable:, live_values:, zabbix_status:)
    @cable = cable
    @live_values = live_values || {}
    @zabbix_status = zabbix_status
  end

  def call
    metrics = collect_metrics
    max_utilization_pct = [ metrics[:upload_utilization_pct], metrics[:download_utilization_pct] ].compact.max

    operational_state = derive_operational_state(
      zabbix_status: @zabbix_status,
      max_utilization_pct: max_utilization_pct,
      has_any_traffic: metrics[:has_any_traffic],
      has_physical_alert: metrics[:has_physical_alert]
    )

    {
      operational_state: operational_state,
      traffic_level: traffic_level_for(max_utilization_pct, metrics[:has_any_traffic]),
      alert_level: alert_level_for(operational_state),
      upload_bps: metrics[:upload_bps],
      download_bps: metrics[:download_bps],
      upload_utilization_pct: metrics[:upload_utilization_pct],
      download_utilization_pct: metrics[:download_utilization_pct],
      max_utilization_pct: round_pct(max_utilization_pct),
      capacity_mbps: @cable.bandwidth_mbps,
      error_in: metrics[:error_in],
      error_out: metrics[:error_out],
      crc_in: metrics[:crc_in],
      crc_out: metrics[:crc_out],
      lastclock: metrics[:lastclock],
      thresholds: thresholds
    }
  end

  private

  def collect_metrics
    upload_bps = numeric_total_for("bandwidth_out")
    download_bps = numeric_total_for("bandwidth_in")
    error_in = numeric_total_for("error_in")
    error_out = numeric_total_for("error_out")
    crc_in = numeric_total_for("crc_in")
    crc_out = numeric_total_for("crc_out")

    {
      upload_bps: upload_bps,
      download_bps: download_bps,
      upload_utilization_pct: utilization_pct_for(upload_bps),
      download_utilization_pct: utilization_pct_for(download_bps),
      has_any_traffic: [ upload_bps, download_bps ].compact.any?(&:positive?),
      error_in: error_in,
      error_out: error_out,
      crc_in: crc_in,
      crc_out: crc_out,
      has_physical_alert: [ error_in, error_out, crc_in, crc_out ].compact.any?(&:positive?),
      lastclock: latest_clock
    }
  end

  def derive_operational_state(zabbix_status:, max_utilization_pct:, has_any_traffic:, has_physical_alert:)
    return "port_down" if zabbix_status == "down"
    return "physical_alert" if has_physical_alert

    if max_utilization_pct.nil?
      return "traffic_low" if has_any_traffic
      return "up_no_traffic" if zabbix_status == "up"

      return "unknown"
    end

    return "up_no_traffic" if zabbix_status == "up" && max_utilization_pct <= 0.0
    return "no_traffic" if max_utilization_pct <= 0.0
    return "traffic_low" if max_utilization_pct <= thresholds[:low_pct]
    return "traffic_moderate" if max_utilization_pct <= thresholds[:moderate_pct]
    return "traffic_high" if max_utilization_pct <= thresholds[:high_pct]

    "saturation"
  end

  def alert_level_for(operational_state)
    return "critical" if operational_state.in?(%w[port_down physical_alert saturation])
    return "warning" if operational_state == "traffic_high"
    return "unknown" if operational_state == "unknown"

    "ok"
  end

  def traffic_level_for(max_utilization_pct, has_any_traffic)
    return "low" if max_utilization_pct.nil? && has_any_traffic
    return nil if max_utilization_pct.nil?
    return "none" if max_utilization_pct <= 0.0
    return "low" if max_utilization_pct <= thresholds[:low_pct]
    return "moderate" if max_utilization_pct <= thresholds[:moderate_pct]
    return "high" if max_utilization_pct <= thresholds[:high_pct]

    "saturated"
  end

  def utilization_pct_for(value_bps)
    return nil if value_bps.nil?

    capacity_mbps = @cable.bandwidth_mbps.to_f
    return nil unless capacity_mbps.positive?

    round_pct((value_bps / 1_000_000.0) / capacity_mbps * 100.0)
  end

  def round_pct(value)
    return nil if value.nil?

    value.round(2)
  end

  def numeric_total_for(metric_role)
    values = values_for(metric_role)
    return nil if values.empty?

    parsed = values.filter_map do |raw|
      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    return nil if parsed.empty?

    parsed.sum
  end

  def values_for(metric_role)
    @cable.network_cable_items.filter_map do |cable_item|
      next nil unless cable_item.metric_role == metric_role
      item = cable_item.zabbix_item
      next nil unless item

      live = @live_values[item.itemid.to_s]
      live&.dig("value") || item.lastvalue
    end
  end

  def latest_clock
    clocks = @cable.network_cable_items.filter_map do |cable_item|
      item = cable_item.zabbix_item
      next nil unless item

      live = @live_values[item.itemid.to_s]
      clock = live&.dig("clock") || item.lastclock
      normalize_clock(clock)
    end

    clocks.compact.max&.to_s
  end

  def normalize_clock(clock)
    return nil if clock.nil?
    return clock.to_i if clock.is_a?(String) && clock.match?(/\A\d+\z/)
    return clock.to_i if clock.respond_to?(:to_i)

    nil
  end

  def thresholds
    return @thresholds if defined?(@thresholds)

    raw = @cable.metadata.is_a?(Hash) ? @cable.metadata["operational_thresholds"] : nil
    @thresholds = build_thresholds(raw)
  end

  def build_thresholds(raw)
    return DEFAULT_THRESHOLDS.dup unless raw.is_a?(Hash)

    low = parse_threshold(raw["low_pct"], DEFAULT_THRESHOLDS[:low_pct])
    moderate = parse_threshold(raw["moderate_pct"], DEFAULT_THRESHOLDS[:moderate_pct])
    high = parse_threshold(raw["high_pct"], DEFAULT_THRESHOLDS[:high_pct])

    return DEFAULT_THRESHOLDS.dup unless low < moderate && moderate < high

    { low_pct: low, moderate_pct: moderate, high_pct: high }
  end

  def parse_threshold(value, fallback)
    return fallback if value.nil?

    parsed = Float(value)
    return fallback if parsed.negative? || parsed > 100.0

    parsed
  rescue ArgumentError, TypeError
    fallback
  end
end
