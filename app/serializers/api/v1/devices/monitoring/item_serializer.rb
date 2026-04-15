class Api::V1::Devices::Monitoring::ItemSerializer
  # live_values: hash of itemid (string) => { "value" => ..., "clock" => ... }
  # sourced from Zabbix::HistoryCache — takes priority over stale model columns.
  def initialize(item, live_values: {})
    @item        = item
    @live_values = live_values || {}
  end

  def as_json(*)
    {
      id:                @item.id,
      zabbix_item_id:    @item.zabbix_item_id,
      alias:             @item.alias,
      category:          @item.category,
      subcategory:       @item.subcategory,
      usage:             @item.usage,
      display_priority:  @item.display_priority,
      map_visibility:    @item.map_visibility,
      is_primary_metric: @item.is_primary_metric,
      is_health_metric:  @item.is_health_metric,
      metadata:          @item.metadata,
      selected_at:       @item.created_at,
      zabbix_item:       zabbix_item_payload
    }
  end

  private

  def zabbix_item_payload
    zi = @item.zabbix_item
    return unless zi

    live = @live_values[zi.itemid.to_s]

    {
      itemid:    zi.itemid,
      name:      zi.name,
      key:       zi.key_,
      units:     zi.units,
      lastvalue: live&.dig("value") || zi.lastvalue,
      lastclock: live&.dig("clock")&.to_s || zi.lastclock&.to_s
    }
  end
end
