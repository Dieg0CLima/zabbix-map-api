class NetworkMaps::MonitoringPayloadBuilder
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id: @network_map.id,
      pops: pops_payload,
      nodes: nodes_payload,
      cables: cables_payload
    }
  end

  private

  def pops
    @pops ||= @network_map.map_pops.includes(:site).order(:id)
  end

  def nodes
    @nodes ||= @network_map.map_nodes.includes(:device).order(:id)
  end

  def cables
    @cables ||= @network_map.network_cables.includes(:network_link).order(:id)
  end

  def zabbix_connection_id
    @network_map.zabbix_connection_id
  end

  def host_map
    return {} if zabbix_connection_id.blank?

    hostids = nodes.map { |node| node.device&.zabbix_ref.presence || node.zabbix_ref }.compact.uniq
    return {} if hostids.empty?

    Zabbix::Host.where(zabbix_connection_id:, hostid: hostids).index_by(&:hostid)
  end

  def item_map
    return {} if zabbix_connection_id.blank?

    itemids = cables.map { |cable| cable.network_link&.zabbix_item_ref }.compact.uniq
    return {} if itemids.empty?

    Zabbix::Item.where(zabbix_connection_id:, itemid: itemids).index_by(&:itemid)
  end

  def pops_payload
    pops.map do |pop|
      {
        external_id: pop.external_id,
        name: pop.name,
        site: pop.site && {
          external_id: pop.site.external_id,
          name: pop.site.name,
          status: pop.site.status
        },
        zabbix_data: nil
      }
    end
  end

  def nodes_payload
    nodes.map do |node|
      zabbix_ref = node.device&.zabbix_ref.presence || node.zabbix_ref
      host = zabbix_ref.present? ? host_map[zabbix_ref] : nil

      {
        external_id: node.external_id,
        label: node.label,
        device: node.device && {
          external_id: node.device.external_id,
          name: node.device.name,
          zabbix_ref: node.device.zabbix_ref
        },
        zabbix_ref:,
        zabbix_data: host && {
          hostid: host.hostid,
          name: host.name,
          status: host.status,
          available: host.available
        }
      }
    end
  end

  def cables_payload
    cables.map do |cable|
      item_ref = cable.network_link&.zabbix_item_ref
      item = item_ref.present? ? item_map[item_ref] : nil

      {
        external_id: cable.external_id,
        label: cable.label,
        network_link: cable.network_link && {
          external_id: cable.network_link.external_id,
          label: cable.network_link.label,
          zabbix_item_ref: cable.network_link.zabbix_item_ref
        },
        zabbix_data: item && {
          itemid: item.itemid,
          name: item.name,
          lastvalue: item.lastvalue,
          units: item.units
        }
      }
    end
  end
end
