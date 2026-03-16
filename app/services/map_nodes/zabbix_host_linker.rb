class MapNodes::ZabbixHostLinker
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload.dup
  end

  def call
    return @payload unless @payload.key?(:zabbix_host_id)
    return @payload if @payload[:zabbix_host_id].blank?

    host = resolve_host

    if host
      # Host found locally — set the real FK and soft reference.
      @payload[:zabbix_host_id] = host.id
      @payload[:zabbix_ref] ||= host.hostid
    else
      # Host not found in local zabbix_hosts (common in db mode where hosts are
      # fetched live from Zabbix without being synced to the local table).
      # Preserve zabbix_ref for display/reference but nil out zabbix_host_id to
      # avoid a FK violation. The binding can be set later via the panel once synced.
      @payload[:zabbix_ref] ||= @payload[:zabbix_host_id].to_s
      @payload[:zabbix_host_id] = nil
    end

    @payload
  end

  private

  def resolve_host
    return nil if @network_map.zabbix_connection.blank?

    raw = @payload[:zabbix_host_id].to_s.strip
    connection_hosts = @network_map.zabbix_connection.zabbix_hosts

    # Try by Zabbix hostid first (string, e.g. "10105"), then by internal AR id.
    # Placeholder host creation was intentionally removed: silently creating records
    # with fake names pollutes the table and bypasses sync integrity.
    # If the host is not found, the model validation will reject the binding.
    connection_hosts.find_by(hostid: raw) ||
      find_by_internal_id(connection_hosts, raw)
  end

  def find_by_internal_id(connection_hosts, raw)
    return nil unless raw.match?(/\A\d+\z/)

    connection_hosts.find_by(id: raw.to_i)
  end
end
