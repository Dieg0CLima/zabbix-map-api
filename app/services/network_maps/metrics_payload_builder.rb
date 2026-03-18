class NetworkMaps::MetricsPayloadBuilder
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id: @network_map.id,
      collected_at:   Time.current,
      nodes:          element_metrics
    }
  end

  private

  def element_metrics
    @network_map.map_elements
                .where(mappable_type: "Device")
                .includes(mappable: :zabbix_host, map_element_items: :zabbix_item)
                .order(:id)
                .map { |el| build_element_metrics(el) }
  end

  def build_element_metrics(element)
    device = element.mappable

    {
      id:          element.external_id,
      external_id: element.external_id,
      label:       element.display_label,
      device_type: device&.device_type,
      zabbix_host: build_host_data(device&.zabbix_host),
      metrics:     element.map_element_items.map { |mei| build_metric(mei) }
    }
  end

  def build_host_data(host)
    return nil unless host

    {
      id:          host.id,
      hostid:      host.hostid,
      name:        host.name,
      status:      host.status,
      available:   host.available,
      last_seen_at: host.last_seen_at
    }
  end

  def build_metric(map_element_item)
    item = map_element_item.zabbix_item

    {
      map_element_item_id: map_element_item.id,
      alias:               map_element_item.alias,
      display_order:       map_element_item.display_order,
      itemid:              item.itemid,
      name:                item.name,
      key_:                item.key_,
      value_type:          item.value_type,
      units:               item.units,
      status:              item.status,
      state:               item.state,
      lastvalue:           item.lastvalue,
      lastclock:           item.lastclock
    }
  end
end
