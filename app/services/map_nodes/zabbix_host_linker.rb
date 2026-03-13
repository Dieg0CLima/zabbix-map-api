class MapNodes::ZabbixHostLinker
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload.dup
  end

  def call
    return @payload unless @payload.key?(:zabbix_host_id)
    return @payload if @payload[:zabbix_host_id].blank?

    host = resolve_host
    return @payload unless host

    @payload[:zabbix_host_id] = host.id
    @payload[:zabbix_ref] ||= host.hostid
    @payload
  end

  private

  def resolve_host
    return nil if @network_map.zabbix_connection.blank?

    raw = @payload[:zabbix_host_id].to_s.strip
    connection_hosts = @network_map.zabbix_connection.zabbix_hosts

    connection_hosts.find_by(hostid: raw) ||
      find_by_internal_id(connection_hosts, raw) ||
      create_placeholder_host(connection_hosts, raw)
  end

  def find_by_internal_id(connection_hosts, raw)
    return nil unless raw.match?(/\A\d+\z/)

    connection_hosts.find_by(id: raw.to_i)
  end

  def create_placeholder_host(connection_hosts, raw)
    return nil unless raw.match?(/\A\d+\z/)

    connection_hosts.find_or_create_by!(hostid: raw) do |host|
      host.name = "Host #{raw}"
    end
  end
end
