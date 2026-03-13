class ZabbixConnections::HostDropdownFetcher
  class Error < StandardError; end
  class UnsupportedAdapterError < Error; end

  def initialize(connection:, limit: nil)
    @connection = connection
    @limit = limit
  end

  def call
    dropdown_hosts.sort_by { |host| [host[:label].to_s.downcase, host[:hostid].to_s] }
  end

  private

  def dropdown_hosts
    return persisted_dropdown_hosts unless @connection.db_enabled?

    fetched_hosts.map do |host|
      {
        value: host[:hostid].to_s,
        label: host[:name].presence || host[:host].to_s,
        hostid: host[:hostid].to_s,
        available: host_available?(host[:status])
      }
    end
  end

  def persisted_dropdown_hosts
    @connection.zabbix_hosts.order(:name, :hostid).map do |host|
      {
        value: host.hostid.to_s,
        label: host.name,
        hostid: host.hostid.to_s,
        available: host_available?(host.available)
      }
    end
  end

  def fetched_hosts
    Zabbix::DatabaseHostsFetcher.new(connection: @connection, limit: @limit).call
  rescue Zabbix::DatabaseHostsFetcher::UnsupportedAdapterError => e
    raise UnsupportedAdapterError, e.message
  rescue Zabbix::DatabaseHostsFetcher::Error => e
    raise Error, e.message
  end

  def host_available?(value)
    return value if value == true || value == false

    normalized = value.to_s.strip.downcase
    return true if normalized.in?(["1", "true", "up", "available", "enabled", "0"])
    return false if normalized.in?(["2", "false", "down", "unavailable", "disabled"])

    false
  end
end
