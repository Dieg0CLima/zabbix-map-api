class Devices::DashboardPayloadBuilder
  def initialize(device:, limit: nil)
    @device = device
    @limit = limit
  end

  def call
    return default_payload unless connection && host_id

    host = dashboard_host
    return default_payload unless host

    rows = zabbix_item_rows
    data = rows.map { |row| standardized_item(row) }
    attach_history!(data)

    {
      host: host,
      items: data,
      interface_items: data.select { |item| interface_item?(item) }
    }
  rescue Zabbix::DatabaseItemsFetcher::Error, Zabbix::DatabaseConnection::Error
    default_payload
  end

  private

  def default_payload
    { host: nil, items: [], interface_items: [] }
  end

  def connection
    @connection ||= @device.zabbix_connection
  end

  def host_id
    @host_id ||= @device.zabbix_host_id.presence
  end

  def dashboard_host
    return unless host_id

    if connection&.db_enabled?
      payload = Zabbix::DatabaseHostDetailsFetcher.new(connection:, hostid: host_id).call
      payload.slice(:hostid, :name, :status, :available)
    else
      host = connection.zabbix_hosts.find_by(hostid: host_id)
      return unless host

      { hostid: host.hostid, name: host.name, status: host.status, available: host.available }
    end
  end

  def zabbix_item_rows
    return [] unless host_id

    if connection&.db_enabled?
      Zabbix::DatabaseItemsFetcher.new(connection: connection, hostid: host_id, limit: @limit).call
    else
      query = connection.zabbix_items.where(zabbix_host_id: host_id).order(:key_)
      query = query.limit(@limit) if @limit.present?
      query.map do |item|
        {
          "itemid" => item.itemid, "name" => item.name, "key_" => item.key_,
          "value_type" => item.value_type, "units" => item.units, "status" => item.status,
          "metadata" => item.metadata, "lastvalue" => item.lastvalue, "lastclock" => item.lastclock
        }
      end
    end
  end

  def standardized_item(row)
    item = row.to_h.stringify_keys
    {
      itemid: item["itemid"], name: item["name"], key: item["key_"],
      value_type: item["value_type"], units: item["units"], status: item["status"],
      state: item["state"], lastvalue: item["lastvalue"], lastclock: item["lastclock"],
      metadata: item["metadata"] || {}
    }
  end

  def attach_history!(items)
    return if items.blank?

    chart = fetch_history(items.map { |i| i[:itemid] })
    return if chart.blank?

    items.each do |item|
      entry = chart[item[:itemid].to_s]
      next unless entry

      item[:lastvalue]  = entry["value"]
      item[:lastclock]  = entry["clock"]
      item[:lastns]     = entry["ns"]
      item[:history]    = format_history_entry(item, entry)
    end
  end

  def format_history_entry(item, entry)
    {
      itemid:        entry["itemid"],
      clock:         entry["clock"],
      value:         entry["value"],
      ns:            entry["ns"],
      clock_iso:     format_clock(entry["clock"]),
      value_type:    item[:value_type],
      units:         item[:units],
      display_value: Zabbix::MetricFormatter.display_value(
        entry["value"], units: item[:units], value_type: item[:value_type], key: item[:key]
      )
    }
  end

  def fetch_history(itemids)
    return {} unless connection&.db_enabled?

    Zabbix::HistoryCache.new(connection:, itemids: itemids).fetch
  rescue StandardError
    {}
  end

  def format_clock(clock)
    return nil if clock.blank?

    Time.zone.at(clock.to_i).iso8601
  rescue StandardError
    nil
  end

  def interface_item?(item)
    key      = item[:key]&.downcase
    metadata = item[:metadata] || {}
    key&.include?("net.if") ||
      metadata.values.any? { |v| v.to_s.downcase.include?("if") } ||
      metadata["SNMPINDEX"].present?
  end
end
