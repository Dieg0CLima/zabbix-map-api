class NetworkCableItems::PayloadBuilder
  # live_values: Hash from Zabbix::LiveValuesFetcher — { itemid_str => { "value", "clock" } }
  def initialize(network_cable_item:, live_values: {})
    @item        = network_cable_item
    @zabbix_item = network_cable_item.zabbix_item
    @live        = live_values || {}
  end

  def call
    live = @zabbix_item ? @live[@zabbix_item.itemid.to_s] : nil

    {
      id:               @item.id,
      network_cable_id: @item.network_cable_id,
      zabbix_item_id:   @item.zabbix_item_id,
      alias:            @item.alias,
      metric_role:      @item.metric_role,
      display_order:    @item.display_order,
      itemid:           @zabbix_item&.itemid,
      name:             @zabbix_item&.name,
      key_:             @zabbix_item&.key_,
      units:            @zabbix_item&.units,
      lastvalue:        live&.dig("value") || @zabbix_item&.lastvalue,
      lastclock:        live&.dig("clock")&.to_s || @zabbix_item&.lastclock&.to_s
    }
  end
end
