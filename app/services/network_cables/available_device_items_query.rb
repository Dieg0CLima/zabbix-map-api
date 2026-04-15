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
    "interface_status"      => "status"
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

    groups = devices.filter_map { |device| build_device_group(device) }
    groups.presence
  end

  # Resolve quais Devices estão acessíveis a partir de um nó do mapa.
  def devices_from_node(node)
    case node.mappable_type
    when "Device"
      device = node.mappable
      device ? [device] : []
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
        device ? [device] : []
      else
        []
      end
    end
  end

  def build_device_group(device)
    profile = device.monitoring_profile
    return nil unless profile

    items = profile.device_monitoring_items
                   .includes(:zabbix_item)
                   .order(display_priority: :desc, id: :asc)

    built = items.filter_map { |mi| build_item(mi) }
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

  def build_item(monitoring_item)
    zabbix_item = monitoring_item.zabbix_item
    return nil unless zabbix_item

    {
      device_monitoring_item_id: monitoring_item.id,
      zabbix_item_id:            monitoring_item.zabbix_item_id,
      label:                     monitoring_item.suggested_alias,
      category:                  monitoring_item.category,
      suggested_role:            CATEGORY_TO_ROLE[monitoring_item.category],
      key_:                      zabbix_item.key_,
      units:                     zabbix_item.units,
      lastvalue:                 zabbix_item.lastvalue,
      lastclock:                 zabbix_item.lastclock,
      map_visibility:            monitoring_item.map_visibility,
      is_primary_metric:         monitoring_item.is_primary_metric
    }
  end
end
