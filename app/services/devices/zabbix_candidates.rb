# Zabbix hosts (read-only) that expose the given IP, flagged with the device that already owns them.
class Devices::ZabbixCandidates
  def initialize(device:, connection:, ip:)
    @device = device
    @connection = connection
    @ip = ip
  end

  # Raises Zabbix::HostCandidatesFetcher::Error when Zabbix cannot be queried.
  def call
    rows = Zabbix::HostCandidatesFetcher.new(connection: @connection, ip: @ip, limit: Zabbix::HostCandidatesFetcher::MAX_LIMIT).call
    owners = linked_devices(rows.map { |row| row[:hostid].to_s })
    rows.map { |row| row.merge(linked_device: owners[row[:hostid].to_s]) }
  end

  private

  def linked_devices(hostids)
    return {} if hostids.empty?

    ZabbixLink
      .where(organization_id: @connection.organization_id, zabbix_connection_id: @connection.id,
             resource_type: "host", linkable_type: "Device", external_id: hostids)
      .where.not(linkable_id: @device.id)
      .includes(:linkable)
      .each_with_object({}) do |link, owners|
        owners[link.external_id] = { id: link.linkable.id, name: link.linkable.name } if link.linkable
      end
  end
end
