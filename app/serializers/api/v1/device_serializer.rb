class Api::V1::DeviceSerializer
  def initialize(device)
    @device = device
  end

  def as_json(*)
    {
      id: @device.id,
      site_id: @device.site_id,
      name: @device.name,
      hostname: @device.hostname,
      role: @device.role,
      vendor: @device.vendor,
      model: @device.model,
      serial_number: @device.serial_number,
      management_ip: @device.management_ip,
      status: @device.status,
      metadata: @device.metadata,
      zabbix_connection_id: @device.zabbix_connection_id,
      zabbix_host_id: @device.zabbix_host_id,
      zabbix_host: zabbix_host_payload,
      zabbix_interfaces: zabbix_host_interfaces,
      zabbix_items: zabbix_items_payload,
      created_at: @device.created_at,
      updated_at: @device.updated_at
    }
  end

  private

  def zabbix_host_payload
    return if @device.zabbix_host_link.blank?

    {
      hostid: @device.zabbix_host_id,
      label: @device.zabbix_host_label
    }
  end

  def zabbix_host_interfaces
    interfaces = zabbix_host_link_metadata[:interfaces]
    return if interfaces.blank?

    Array(interfaces).map do |interface|
      interface.with_indifferent_access.slice(:ip, :dns, :type, :main)
    end
  end

  def zabbix_host_link_metadata
    @zabbix_host_link_metadata ||= @device.zabbix_host_link&.metadata&.with_indifferent_access || {}
  end

  def zabbix_items_payload
    return if @device.zabbix_host_link.blank?

    connection = @device.zabbix_connection
    host_id = @device.zabbix_host_id
    return if connection.blank? || host_id.blank?

    @zabbix_items_payload ||= fetch_zabbix_items(connection, host_id)
  end

  def fetch_zabbix_items(connection, host_id)
    Zabbix::ItemFinder.new(connection:, host_id: host_id).call
  rescue Zabbix::DatabaseItemsFetcher::Error, Zabbix::DatabaseConnection::Error => e
    Rails.logger.warn("[DeviceSerializer] falling back to cached items for host #{host_id}: #{e.message}")
    connection.zabbix_items.where(zabbix_host_id: host_id).limit(100).map do |item|
      {
        value: item.itemid.to_s,
        label: item.name,
        itemid: item.itemid.to_s,
        key: item.key_
      }
    end
  end
end
