class Devices::ZabbixHostLinkUpserter
  def initialize(device:, organization:, params:)
    @device = device
    @organization = organization
    @params = params
  end

  def call
    attrs = extract_attrs
    return unless attrs.key?(:zabbix_host_id) || attrs.key?(:zabbix_connection_id)

    host_id = attrs[:zabbix_host_id].to_s.strip
    connection_id = attrs[:zabbix_connection_id].presence

    if host_id.blank? && connection_id.blank?
      @device.zabbix_host_link&.destroy!
      return
    end

    if host_id.blank? || connection_id.blank?
      @device.errors.add(:base, "zabbix_connection_id and zabbix_host_id must be provided together")
      raise ActiveRecord::RecordInvalid, @device
    end

    connection = @organization.zabbix_connections.find_by(id: connection_id)
    unless connection
      @device.errors.add(:zabbix_connection_id, "not found")
      raise ActiveRecord::RecordInvalid, @device
    end

    host = connection.zabbix_hosts.find_by(hostid: host_id)
    unless host
      @device.errors.add(:zabbix_host_id, "not found for this Zabbix connection")
      raise ActiveRecord::RecordInvalid, @device
    end

    link = @device.zabbix_host_link || @device.zabbix_links.build(resource_type: "host")
    link.organization = @organization
    link.zabbix_connection = connection
    link.resource_type = "host"
    link.external_id = host.hostid.to_s
    link.external_key = host.respond_to?(:id) ? host.id.to_s : nil
    link.name = host.name
    link.metadata = build_metadata(host)
    link.save!

    cleanup_duplicate_host_links(link)
  end

  private

  def extract_attrs
    @params.slice(:zabbix_connection_id, :zabbix_host_id)
  end

  def build_metadata(host)
    existing = @device.zabbix_host_link&.metadata || {}
    existing.merge(
      "hostid" => host.hostid.to_s,
      "name" => host.name,
      "available" => host.available,
      "status" => host.status,
      "interfaces" => host.interfaces,
      "synced_at" => Time.current.iso8601
    )
  end

  def cleanup_duplicate_host_links(link)
    @device.zabbix_links.where(resource_type: "host").where.not(id: link.id).destroy_all
  end
end
