class Api::V1::Devices::Monitoring::AvailableItemSerializer
  def initialize(item)
    @item = item
  end

  def as_json(*)
    {
      item_id: @item[:item_id],
      zabbix_item_id: @item[:zabbix_item_id],
      label: @item[:label],
      key: @item[:key],
      units: @item[:units],
      value_type: @item[:value_type],
      category_hint: @item[:category_hint],
      suggested_alias: @item[:suggested_alias],
      map_visibility: @item[:map_visibility],
      metadata: @item[:metadata]
    }
  end
end
