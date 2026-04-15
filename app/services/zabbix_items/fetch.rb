class ZabbixItems::Fetch
  def initialize(connection:, hostid:, zabbix_host_id:, limit:)
    @connection = connection
    @hostid = hostid
    @zabbix_host_id = zabbix_host_id
    @limit = limit
  end

  def call
    ZabbixItems::SummaryFetcher.new(
      connection: @connection,
      hostid: @hostid,
      zabbix_host_id: @zabbix_host_id,
      limit: @limit
    ).call.items
  end
end
