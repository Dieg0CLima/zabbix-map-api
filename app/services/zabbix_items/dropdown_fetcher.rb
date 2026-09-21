class ZabbixItems::DropdownFetcher
  Result = Struct.new(:items, :meta, keyword_init: true)

  def initialize(connection:, zabbix_host_id: nil)
    @connection = connection
    @zabbix_host_id = zabbix_host_id.to_s.strip.presence
  end

  def call
    items = rows.map { |item| build_item(item) }
    Result.new(items: items, meta: { connection_id: connection.id, count: items.size })
  end

  private

  attr_reader :connection, :zabbix_host_id

  def rows
    scope = connection.zabbix_items.order(:name)
    scope = scope.where(zabbix_host_id: zabbix_host_id) if zabbix_host_id.present?
    scope
  end

  def build_item(item)
    {
      value: item.id,
      label: "#{item.name} (#{item.key_})",
      itemid: item.itemid,
      units: item.units,
      value_type: item.value_type
    }
  end
end
