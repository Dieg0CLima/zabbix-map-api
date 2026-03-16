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
    if @hostid.present?
      # Filter by Zabbix hostid string (e.g. "10559") via join — works in API mode
      # where items ARE synced locally but the frontend always sends the hostid string.
      scoped_items = scoped_items.joins(:host).where(zabbix_hosts: { hostid: @hostid })
    elsif @zabbix_host_id.present?
      scoped_items = scoped_items.where(zabbix_host_id: @zabbix_host_id)
    end
    scoped_items
  end
end
