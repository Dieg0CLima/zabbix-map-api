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

    host_reference = fetch_host_reference(connection, host_id)

    link = @device.zabbix_host_link || @device.zabbix_links.build(resource_type: "host")
    link.organization = @organization
    link.zabbix_connection = connection
    link.resource_type = "host"
    link.external_id = host_reference[:hostid].to_s
    link.external_key = nil
    link.name = host_reference[:name]
    link.metadata = build_metadata(host_reference)
    link.save!

    cleanup_duplicate_host_links(link)
  end

  private

  def extract_attrs
    @params.slice(:zabbix_connection_id, :zabbix_host_id)
  end

  def fetch_host_reference(connection, host_id)
    Zabbix::HostDetailsFetcher.new(connection:, hostid: host_id).reference_payload
  rescue Zabbix::HostDetailsFetcher::UnsupportedAdapterError => e
    @device.errors.add(:zabbix_connection_id, e.message)
    raise ActiveRecord::RecordInvalid, @device
  rescue Zabbix::HostDetailsFetcher::Error => e
    @device.errors.add(:zabbix_host_id, e.message)
    raise ActiveRecord::RecordInvalid, @device
  end

  def build_metadata(host_reference)
    existing = @device.zabbix_host_link&.metadata || {}
    existing.merge(
      "hostid" => host_reference[:hostid].to_s,
      "name" => host_reference[:name],
      "available" => host_reference[:available],
      "status" => host_reference[:status],
      "interfaces" => host_reference[:interfaces],
      "metadata" => host_reference[:metadata],
      "synced_at" => Time.current.iso8601
    )
  end

  def cleanup_duplicate_host_links(link)
    @device.zabbix_links.where(resource_type: "host").where.not(id: link.id).destroy_all
  end
end
