class NetworkCables::OperationalVisualProfile
  CABLE_STATUS_COLORS = {
    "active" => "#059669",
    "maintenance" => "#f97316",
    "planned" => "#64748b",
    "disabled" => "#dc2626"
  }.freeze

  ZABBIX_STATUS_COLORS = {
    "up" => "#059669",
    "down" => "#dc2626",
    "degraded" => "#d97706",
    "unknown" => "#64748b"
  }.freeze

  ALERT_LEVEL_COLORS = {
    "critical" => "#dc2626",
    "warning" => "#d97706",
    "ok" => "#059669",
    "unknown" => "#64748b"
  }.freeze

  TRAFFIC_LEVEL_COLORS = {
    "none" => "#000000",
    "low" => "#16a34a",
    "moderate" => "#ca8a04",
    "high" => "#d97706",
    "saturated" => "#dc2626"
  }.freeze

  OPERATIONAL_STATE_LABELS = {
    "port_down" => "Porta down",
    "physical_alert" => "Alerta físico",
    "up_no_traffic" => "UP sem tráfego",
    "no_traffic" => "Sem tráfego",
    "traffic_low" => "Tráfego baixo",
    "traffic_moderate" => "Tráfego moderado",
    "traffic_high" => "Tráfego alto",
    "saturation" => "Saturação",
    "unknown" => "Desconhecido"
  }.freeze

  def initialize(cable_status:, zabbix_status:, operational_state:, traffic_level:, alert_level:)
    @cable_status = cable_status.to_s
    @zabbix_status = normalize_zabbix_status(zabbix_status)
    @operational_state = operational_state.to_s
    @traffic_level = traffic_level.to_s
    @alert_level = normalize_alert_level(alert_level)
  end

  def call
    {
      cable_color: cable_color,
      indicator_color: cable_color,
      status_color: status_color,
      alert_color: alert_color,
      traffic_color: traffic_color,
      indicator_severity: indicator_severity,
      state_label: state_label
    }
  end

  private

  def cable_color
    return no_traffic_color if no_traffic_state?
    return alert_color if %w[critical warning].include?(@alert_level)
    return status_color if @zabbix_status != "unknown"

    base_status_color
  end

  def status_color
    ZABBIX_STATUS_COLORS.fetch(@zabbix_status, ZABBIX_STATUS_COLORS["unknown"])
  end

  def alert_color
    ALERT_LEVEL_COLORS.fetch(@alert_level, ALERT_LEVEL_COLORS["unknown"])
  end

  def traffic_color
    TRAFFIC_LEVEL_COLORS.fetch(@traffic_level, no_traffic_color)
  end

  def indicator_severity
    return "danger" if @alert_level == "critical"
    return "warn" if @alert_level == "warning"
    return "success" if @alert_level == "ok"

    "secondary"
  end

  def state_label
    OPERATIONAL_STATE_LABELS[@operational_state] || @operational_state.presence || "Desconhecido"
  end

  def base_status_color
    CABLE_STATUS_COLORS.fetch(@cable_status, CABLE_STATUS_COLORS["active"])
  end

  def no_traffic_state?
    @operational_state.in?(%w[up_no_traffic no_traffic]) || @traffic_level == "none"
  end

  def no_traffic_color
    "#000000"
  end

  def normalize_zabbix_status(value)
    normalized = value.to_s.strip.downcase
    return normalized if ZABBIX_STATUS_COLORS.key?(normalized)

    "unknown"
  end

  def normalize_alert_level(value)
    normalized = value.to_s.strip.downcase
    return normalized if ALERT_LEVEL_COLORS.key?(normalized)

    "unknown"
  end
end
