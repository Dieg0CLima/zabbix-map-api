# Fetches live lastvalue/lastclock for an array of Zabbix::Item records by
# querying the Zabbix history database through Zabbix::HistoryCache.
#
# Items are grouped by zabbix_connection_id so a single HistoryCache call is
# made per connection, and the ZabbixConnection records are pre-loaded in one
# query to avoid N+1.
#
# Returns a Hash keyed by itemid (String):
#   { "12345" => { "value" => "123.45", "clock" => "1712345678" }, ... }
#
# Falls back to an empty hash when the connection is not db-enabled or on any
# error, so callers can always fall back to stale model columns.
#
# Usage:
#   zabbix_items = network_cable_items.filter_map(&:zabbix_item)
#   live = Zabbix::LiveValuesFetcher.new(items: zabbix_items).call
#   lastvalue = live.dig(item.itemid.to_s, "value") || item.lastvalue
class Zabbix::LiveValuesFetcher
  def initialize(items:)
    @items = Array(items).compact
  end

  def call
    return {} if @items.empty?

    connection_ids = @items.map(&:zabbix_connection_id).uniq.compact
    return {} if connection_ids.empty?

    connections_by_id = ZabbixConnection.where(id: connection_ids).index_by(&:id)

    result = {}

    @items.group_by(&:zabbix_connection_id).each do |conn_id, conn_items|
      connection = connections_by_id[conn_id]
      next unless connection&.db_enabled?

      itemids        = conn_items.map { |i| i.itemid.to_s }
      value_type_map = conn_items.each_with_object({}) { |i, h| h[i.itemid.to_s] = i.value_type.to_s }

      live = Zabbix::HistoryCache.new(
        connection:    connection,
        itemids:       itemids,
        value_type_map: value_type_map
      ).fetch

      result.merge!(live)
    rescue StandardError => e
      Rails.logger.warn { "Zabbix::LiveValuesFetcher error for connection #{conn_id}: #{e.class}: #{e.message}" }
    end

    result
  end
end
