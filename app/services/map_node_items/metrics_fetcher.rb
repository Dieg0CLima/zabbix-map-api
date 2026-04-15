module MapNodeItems
  class MetricsFetcher
    def initialize(network_map:, map_node:, items: nil)
      @network_map = network_map
      @map_node = map_node
      @items = Array(items || map_node.map_node_items.includes(zabbix_item: :host).order(:display_order, :id))
    end

    def call
      return [] if items.empty?

      history = fetch_live_history
      items.filter_map do |map_node_item|
        build_metric_payload(map_node_item, history)
      end
    end

    private

    attr_reader :network_map, :map_node, :items

    def fetch_live_history
      return {} unless network_map.zabbix_connection&.db_enabled?

      loaded = items.select { |i| i.zabbix_item.present? }
      return {} if loaded.empty?

      itemids        = loaded.map { |i| i.zabbix_item.itemid }
      value_type_map = loaded.each_with_object({}) { |i, h| h[i.zabbix_item.itemid.to_s] = i.zabbix_item.value_type.to_s }

      Zabbix::HistoryCache.new(
        connection:     network_map.zabbix_connection,
        itemids:        itemids,
        value_type_map: value_type_map
      ).fetch
    rescue StandardError
      {}
    end

    def build_metric_payload(map_node_item, history)
      item = map_node_item.zabbix_item
      return nil unless item

      live = history[item.itemid.to_s] if history.present?
      lastvalue, lastclock = metric_values(item, live)

      {
        map_node_item_id: map_node_item.id,
        map_node_external_id: map_node.external_id,
        map_node_id: map_node.id,
        alias: map_node_item.alias,
        display_order: map_node_item.display_order,
        itemid: item.itemid,
        name: item.name,
        key: item.key_,
        units: item.units,
        value_type: item.value_type,
        hostid: item.host&.hostid,
        status: item.status,
        state: item.state,
        lastvalue: lastvalue,
        lastclock: lastclock,
        lastclock_iso: clock_to_iso(lastclock),
        display_value: display_value(lastvalue, item.units),
        data_source: history.present? && live.present? ? "live" : "cache"
      }
    end

    def metric_values(item, live)
      if live.present?
        [live["value"], live["clock"]]
      else
        [item.lastvalue, item.lastclock&.to_i]
      end
    end

    def clock_to_iso(clock)
      return nil if clock.blank?
      Time.at(clock.to_i).utc.iso8601
    rescue StandardError
      nil
    end

    def display_value(lastvalue, units)
      return nil if lastvalue.blank?
      return lastvalue if units.blank?
      "#{lastvalue} #{units}"
    end
  end
end
