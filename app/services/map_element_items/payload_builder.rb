module MapElementItems
  class PayloadBuilder
    def initialize(map_element_item:)
      @item = map_element_item
    end

    def call
      zabbix_item = @item.zabbix_item

      {
        id:              @item.id,
        map_element_id:  @item.map_element_id,
        zabbix_item_id:  @item.zabbix_item_id,
        alias:           @item.alias,
        display_order:   @item.display_order,
        zabbix_item:     zabbix_item_payload(zabbix_item),
        created_at:      @item.created_at,
        updated_at:      @item.updated_at
      }
    end

    private

    def zabbix_item_payload(item)
      return nil unless item

      {
        id:         item.id,
        itemid:     item.itemid,
        name:       item.name,
        key_:       item.key_,
        value_type: item.value_type,
        units:      item.units,
        status:     item.status,
        state:      item.state,
        lastvalue:  item.lastvalue,
        lastclock:  item.lastclock
      }
    end
  end
end
