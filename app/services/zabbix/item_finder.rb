class Zabbix::ItemFinder
  def initialize(connection:, host_id:, limit: 100)
    @connection = connection
    @host_id = host_id
    @limit = limit
  end

  def call
    ZabbixItems::Fetch.new(connection: @connection, hostid: @host_id, zabbix_host_id: nil, limit: @limit).call.map do |item|
      if item.respond_to?(:itemid)
        { value: item.itemid.to_s, label: item.name, itemid: item.itemid.to_s, key: item.key_ }
      else
        { value: item[:itemid].to_s, label: item[:name], itemid: item[:itemid].to_s, key: item[:key_] }
      end
    end
  end
end
