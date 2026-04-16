# Retorna os DeviceMonitoringItems dos Devices acessíveis pelos extremos de um cabo.
#
# Um nó pode apontar diretamente para um Device (mappable_type: "Device") ou para
# um Site (mappable_type: "Site"). No caso de Site, todos os Devices do Site que
# possuam perfil de monitoramento são incluídos, agrupados por Device.
#
# Resposta por lado:
#   { source: [ { device: {...}, items: [...] }, ... ], target: [...] }
class NetworkCables::AvailableDeviceItemsQuery
  CATEGORY_TO_ROLE = {
    "interface_traffic_in"  => "bandwidth_in",
    "interface_traffic_out" => "bandwidth_out",
    "interface_status"      => "status",
    "interface_crc_in"      => "crc_in",
    "interface_crc_out"     => "crc_out"
  }.freeze

  def initialize(cable:)
    @cable = cable
  end

  def call
    result = {}

    { source: @cable.source_node, target: @cable.target_node }.each do |side, node|
      groups = build_side(node)
      result[side] = groups if groups&.any?
    end

    result
  end

  private

  def build_side(node)
    return nil if node.nil?

    devices = devices_from_node(node)
    return nil if devices.empty?

    live_values = fetch_live_values(devices)
    groups = devices.filter_map { |device| build_device_group(device, live_values: live_values) }
    groups.presence
  end

  # Resolve quais Devices estão acessíveis a partir de um nó do mapa.
  def devices_from_node(node)
    case node.mappable_type
    when "Device"
      device = node.mappable
      device ? [ device ] : []
    when "Site"
      site = node.mappable
      return [] unless site

      site.devices
          .includes(monitoring_profile: { device_monitoring_items: :zabbix_item })
          .select { |d| d.monitoring_profile.present? }
    else
      # Fallback: campo legado device_id
      if node.device_id.present?
        device = Device.find_by(id: node.device_id)
        device ? [ device ] : []
      else
        []
      end
    end
  end

  def build_device_group(device, live_values:)
    profile = device.monitoring_profile
    return nil unless profile

    items = profile.device_monitoring_items
                   .includes(:zabbix_item)
                   .order(display_priority: :desc, id: :asc)

    built = items.filter_map { |mi| build_item(mi, live_values: live_values) }
    return nil if built.empty?

    {
      device: {
        id:          device.id,
        name:        device.name,
        external_id: device.external_id,
        role:        device.role
      },
      items: built
    }
  end

  def build_item(monitoring_item, live_values:)
    zabbix_item = monitoring_item.zabbix_item
    return nil unless zabbix_item

    live = live_values[zabbix_item.itemid.to_s]

    {
      device_monitoring_item_id: monitoring_item.id,
      zabbix_item_id:            monitoring_item.zabbix_item_id,
      label:                     monitoring_item.suggested_alias,
      category:                  monitoring_item.category,
      suggested_role:            suggested_role_for(monitoring_item, zabbix_item),
      key_:                      zabbix_item.key_,
      units:                     zabbix_item.units,
      lastvalue:                 live&.dig("value") || zabbix_item.lastvalue,
      lastclock:                 live&.dig("clock")&.to_s || zabbix_item.lastclock&.to_s,
      map_visibility:            monitoring_item.map_visibility,
      is_primary_metric:         monitoring_item.is_primary_metric
    }
  end

  def fetch_live_values(devices)
    zabbix_items = devices.flat_map do |device|
      profile = device.monitoring_profile
      next [] unless profile

      profile.device_monitoring_items.filter_map(&:zabbix_item)
    end

    Zabbix::LiveValuesFetcher.new(items: zabbix_items).call
  end

  def suggested_role_for(monitoring_item, zabbix_item)
    role = CATEGORY_TO_ROLE[monitoring_item.category]
    return role if role.present?

    return infer_error_role(zabbix_item) if monitoring_item.category.in?(%w[interface_errors interface_discards])

    nil
  end

  def infer_error_role(zabbix_item)
    text = [ zabbix_item.key_, zabbix_item.name ].compact.join(" ").downcase

    direction =
      if text.match?(/(\.in\b|ifin|rx|receive|input|incoming)/)
        "in"
      elsif text.match?(/(\.out\b|ifout|tx|transmit|output|outgoing)/)
        "out"
      end

    return nil if direction.blank?

    if text.include?("crc") || text.include?("fcs")
      "crc_#{direction}"
    else
      "error_#{direction}"
    end
  end
end
