class Devices::ZabbixHostLinkUpserter
  def initialize(device:, organization:, params:)
    @device = device
    @organization = organization
    @params = params
  end

  # Returns how many monitoring items/bindings of the previous host were removed
  # (only when the device is relinked to a different host).
  def call
    attrs = extract_attrs
    return no_removal unless attrs.key?(:zabbix_host_id) || attrs.key?(:zabbix_connection_id)

    host_id = attrs[:zabbix_host_id].to_s.strip
    connection_id = attrs[:zabbix_connection_id].presence

    if host_id.blank? && connection_id.blank?
      @device.zabbix_host_link&.destroy!
      return no_removal
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
    relink(connection, host_reference)
  rescue ActiveRecord::RecordNotUnique
    add_conflict_error(nil)
    raise ActiveRecord::RecordInvalid, @device
  end

  private

  def no_removal
    { items: 0, bindings: 0 }
  end

  def relink(connection, host_reference)
    hostid = host_reference[:hostid].to_s

    ActiveRecord::Base.transaction do
      ensure_host_not_linked_elsewhere!(connection, hostid)

      existing = @device.zabbix_host_link
      removed = existing && host_changed?(existing, connection, hostid) ? purge_monitoring(existing) : no_removal

      link = existing || @device.zabbix_links.build(resource_type: "host")
      link.organization = @organization
      link.zabbix_connection = connection
      link.resource_type = "host"
      link.external_id = hostid
      link.external_key = nil
      link.name = host_reference[:name]
      link.metadata = build_metadata(host_reference)
      link.save!

      cleanup_duplicate_host_links(link)
      removed
    end
  end

  def host_changed?(link, connection, hostid)
    link.external_id.to_s != hostid || link.zabbix_connection_id != connection.id
  end

  # RN8: items and bindings belong to the old host and are not migrated to the new one.
  def purge_monitoring(link)
    items = @device.monitoring_profile ? @device.monitoring_profile.device_monitoring_items.destroy_all.size : 0
    bindings = MapMonitoringBinding.where(zabbix_link_id: link.id).destroy_all.size
    { items: items, bindings: bindings }
  end

  def ensure_host_not_linked_elsewhere!(connection, hostid)
    owner = ZabbixLink
            .where(organization_id: @organization.id, zabbix_connection_id: connection.id, resource_type: "host", external_id: hostid)
            .where.not(linkable_type: "Device", linkable_id: @device.id)
            .first
    return unless owner

    add_conflict_error(owner)
    raise ActiveRecord::RecordInvalid, @device
  end

  def add_conflict_error(owner)
    name = owner&.linkable.try(:name)
    message = if name.present?
      "Este host do Zabbix já está vinculado ao equipamento \"#{name}\". Desvincule-o de lá ou escolha outro host."
    else
      "Este host do Zabbix já está vinculado a outro equipamento. Desvincule-o de lá ou escolha outro host."
    end
    @device.errors.add(:zabbix_host_id, message)
  end

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
