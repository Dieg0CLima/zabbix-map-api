class ZabbixHosts::Fetch
  def initialize(connection:, limit:)
    @connection = connection
    @limit = limit
  end

  def call
    return @connection.zabbix_hosts.order(:id) unless @connection.db_enabled?

    Zabbix::DatabaseHostsFetcher.new(connection: @connection, limit: @limit).call
  end
end
