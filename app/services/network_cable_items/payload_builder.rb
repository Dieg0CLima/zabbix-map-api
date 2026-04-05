class NetworkCableItems::PayloadBuilder
  def initialize(network_cable_item:)
    @item = network_cable_item
    @zabbix_item = network_cable_item.zabbix_item
  end

  def call
    {
      id: @item.id,
      network_cable_id: @item.network_cable_id,
      zabbix_item_id: @item.zabbix_item_id,
      alias: @item.alias,
      metric_role: @item.metric_role,
      display_order: @item.display_order,
      zabbix_item: zabbix_item_data,
      created_at: @item.created_at,
      updated_at: @item.updated_at
    }
  end

  private

  def zabbix_item_data
    return nil unless @zabbix_item

    {
      id: @zabbix_item.id,
      itemid: @zabbix_item.itemid,
      name: @zabbix_item.name,
      key_: @zabbix_item.key_,
      value_type: @zabbix_item.value_type,
      units: @zabbix_item.units,
      status: @zabbix_item.status,
      state: @zabbix_item.state,
      lastvalue: @zabbix_item.lastvalue,
      lastclock: @zabbix_item.lastclock
    }
  end
end
