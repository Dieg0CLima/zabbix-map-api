class ZabbixHosts::ItemsFetcher
  DEFAULT_LIMIT = 500

  class Error < StandardError; end

  def initialize(connection:, hostid:, limit: nil)
    @connection = connection
    @hostid = hostid.to_s.strip
    @limit = [limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT, 2_000].min
  end

  def call
    raw_items = fetch_raw_items
    local_host = find_or_upsert_host
    upserted = upsert_items(raw_items, local_host)
    build_dropdown(upserted)
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    raise Error, e.message
  end

  private

  def fetch_raw_items
    if @connection.db_enabled?
      Zabbix::DatabaseItemsFetcher.new(
        connection: @connection,
        hostid: @hostid,
        limit: @limit
      ).call
    else
      @connection.zabbix_items
                 .includes(:host)
                 .where(zabbix_hosts: { hostid: @hostid })
                 .order(:name)
                 .limit(@limit)
                 .map do |item|
                   {
                     itemid: item.itemid,
                     name: item.name,
                     key_: item.key_,
                     value_type: item.value_type,
                     units: item.units,
                     status: item.status
                   }
                 end
    end
  end

  def find_or_upsert_host
    @connection.zabbix_hosts.find_by(hostid: @hostid)
  end

  def upsert_items(raw_items, local_host)
    return [] if raw_items.empty?

    raw_items.map do |raw|
      existing = @connection.zabbix_items.find_by(itemid: raw[:itemid])

      if existing
        existing.tap do |item|
          item.update_columns(
            name: raw[:name],
            key_: raw[:key_],
            value_type: raw[:value_type].to_s,
            units: raw[:units].to_s,
            status: raw[:status].to_s,
            zabbix_host_id: local_host&.id
          ) if item_changed?(item, raw, local_host)
        end
      else
        @connection.zabbix_items.create!(
          itemid: raw[:itemid],
          name: raw[:name],
          key_: raw[:key_],
          value_type: raw[:value_type].to_s,
          units: raw[:units].to_s,
          status: raw[:status].to_s,
          zabbix_host_id: local_host&.id
        )
      end
    end.compact
  rescue ActiveRecord::RecordInvalid
    []
  end

  def item_changed?(item, raw, local_host)
    item.name != raw[:name] ||
      item.key_ != raw[:key_] ||
      item.value_type.to_s != raw[:value_type].to_s ||
      item.units.to_s != raw[:units].to_s ||
      item.status.to_s != raw[:status].to_s ||
      item.zabbix_host_id != local_host&.id
  end

  def build_dropdown(items)
    items.map do |item|
      {
        value: item.id,
        label: "#{item.name} (#{item.key_})",
        itemid: item.itemid,
        units: item.units,
        value_type: item.value_type
      }
    end.sort_by { |i| i[:label].to_s.downcase }
  end
end
