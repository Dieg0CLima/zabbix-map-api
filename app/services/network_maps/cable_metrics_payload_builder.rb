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
    @network_map.network_cables
                .includes(network_cable_items: :zabbix_item)
                .order(:id)
                .map { |cable| build_cable_metrics(cable) }
  end

  def build_cable_metrics(cable)
    {
      id: cable.id,
      external_id: cable.external_id,
      label: cable.label,
      status: cable.status,
      zabbix_status: derive_zabbix_status(cable),
      items: cable.network_cable_items.map { |ci| build_item(ci) }
    }
  end

  def derive_zabbix_status(cable)
    status_item = cable.network_cable_items.find { |ci| ci.metric_role == "status" }
    return nil unless status_item&.zabbix_item

    value = status_item.zabbix_item.lastvalue.to_s.strip.downcase
    # ifOperStatus: 1=up, 2=down; or textual "up"/"down"
    return "up" if value == "1" || value == "up"
    return "down" if value == "2" || value == "down"

    nil
  end

  def build_item(cable_item)
    zabbix_item = cable_item.zabbix_item

    {
      id: cable_item.id,
      network_cable_id: cable_item.network_cable_id,
      zabbix_item_id: cable_item.zabbix_item_id,
      alias: cable_item.alias,
      metric_role: cable_item.metric_role,
      display_order: cable_item.display_order,
      itemid: zabbix_item&.itemid,
      name: zabbix_item&.name,
      key_: zabbix_item&.key_,
      units: zabbix_item&.units,
      lastvalue: zabbix_item&.lastvalue,
      lastclock: zabbix_item&.lastclock
    }
  end
end
