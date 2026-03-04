class ZabbixItems::Fetch
  def initialize(connection:, hostid:, zabbix_host_id:, limit:)
    @connection = connection
    @hostid = hostid
    @zabbix_host_id = zabbix_host_id
    @limit = limit
  end

  def call
    return filtered_api_items unless @connection.db_enabled?

    Zabbix::DatabaseItemsFetcher.new(
      connection: @connection,
      hostid: @hostid,
      limit: @limit
    ).call
  end

  private

  def filtered_api_items
    scoped_items = @connection.zabbix_items.order(:id)
    scoped_items = scoped_items.where(zabbix_host_id: @zabbix_host_id) if @zabbix_host_id.present?
    scoped_items
  end
end
