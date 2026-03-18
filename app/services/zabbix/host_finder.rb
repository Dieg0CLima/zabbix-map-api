class Zabbix::HostFinder
  def initialize(connection:, query: nil, limit: 100)
    @connection = connection
    @query = query
    @limit = limit
  end

  def call
    ZabbixConnections::HostDropdownFetcher.new(connection: @connection, query: @query, limit: @limit).call
  end
end
