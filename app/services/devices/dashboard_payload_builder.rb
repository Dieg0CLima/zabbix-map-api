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
      {
        hostid: payload[:hostid],
        name: payload[:name],
        status: payload[:status],
        available: payload[:available]
      }
    else
      host = connection.zabbix_hosts.find_by(hostid: host_id)
      return unless host

      {
        hostid: host.hostid,
        name: host.name,
        status: host.status,
        available: host.available
      }
    end
  end

  def zabbix_item_rows
    return [] unless host_id

    if connection&.db_enabled?
      Zabbix::DatabaseItemsFetcher.new(
        connection: connection,
        hostid: host_id,
        limit: @limit
      ).call
    else
      query = connection.zabbix_items.where(zabbix_host_id: host_id)
      query = query.order(:key_)
      query = query.limit(@limit) if @limit.present?
      query.map do |item|
        {
          "itemid" => item.itemid,
          "name" => item.name,
          "key_" => item.key_,
          "value_type" => item.value_type,
          "units" => item.units,
          "status" => item.status,
          "metadata" => item.metadata,
          "lastvalue" => item.lastvalue,
          "lastclock" => item.lastclock
        }
      end
    end
  end

  def standardized_item(row)
    item = row.to_h.stringify_keys

    {
      itemid: item["itemid"],
      name: item["name"],
      key: item["key_"],
      value_type: item["value_type"],
      units: item["units"],
      status: item["status"],
      state: item["state"],
      lastvalue: item["lastvalue"],
      lastclock: item["lastclock"],
      metadata: item["metadata"] || {}
    }
  end

  def attach_history!(items)
    return if items.blank?

    chart = fetch_history(items.map { |item| item[:itemid] })
    return if chart.blank?

    items.each do |item|
      history = chart[item[:itemid]]
      next unless history

      formatted_history = format_history_entry(item, history)
      item[:history] = formatted_history
      item[:lastvalue] = formatted_history[:value]
      item[:lastclock] = formatted_history[:clock]
      item[:lastns] = formatted_history[:ns]
    end
  end

  def format_history_entry(item, history)
    formatted = history.slice("itemid", "clock", "value", "ns").transform_keys(&:to_sym)
    formatted[:clock_iso] = format_clock(history["clock"])
    formatted[:value_type] = item[:value_type]
    formatted[:units] = item[:units]
    formatted[:display_value] = display_value(item, history["value"])
    formatted
  end

  def display_value(item, raw_value)
    return nil if raw_value.nil?

    if uptime_metric?(item)
      format_uptime(raw_value)
    elsif throughput_metric?(item)
      format_throughput(raw_value)
    elsif numeric_value?(item[:value_type])
      units = item[:units].to_s.strip
      value = formatted_number(raw_value)
      units.present? ? "#{value} #{units}" : value
    else
      raw_value.to_s
    end
  end

  def uptime_metric?(item)
    key = item[:key].to_s
    units = item[:units].to_s.strip.downcase
    units == "uptime" || key.include?("system.uptime")
  end

  def format_uptime(raw_value)
    seconds = BigDecimal(raw_value.to_s).to_i
    days, remaining = seconds.divmod(86_400)
    hours, remaining = remaining.divmod(3_600)
    minutes, remaining = remaining.divmod(60)
    parts = []
    parts << "#{days}d" if days.positive?
    parts << "#{hours}h" if hours.positive?
    parts << "#{minutes}m" if minutes.positive?
    parts << "#{remaining}s" if parts.empty? || remaining.positive?
    parts.join(" ")
  rescue ArgumentError, TypeError
    formatted_number(raw_value)
  end


  def throughput_metric?(item)
    units = item[:units].to_s.strip.downcase
    key = item[:key].to_s.downcase
    units.include?("bps") || key.include?("net.if")
  end

  def format_throughput(raw_value)
    value = BigDecimal(raw_value.to_s)
    units = %w[bps Kbps Mbps Gbps Tbps]
    scale = 0
    while value >= 1000 && scale < units.size - 1
      value /= 1000
      scale += 1
    end
    value = value.round(2)
    formatted = strip_trailing_zeros(value)
    "#{formatted} #{units[scale]}"
  rescue ArgumentError, TypeError
    formatted_number(raw_value)
  end

  def strip_trailing_zeros(value)
    str = value.to_s('F')
    str.include?(".") ? str.sub(/\.?0+\z/, "") : str
  end

  def numeric_value?(value_type)
    value_type.to_s.in?(%w[0 3])
  end

  def formatted_number(raw)
    BigDecimal(raw.to_s).to_s("F")
  rescue ArgumentError, TypeError
    raw.to_s
  end

  def format_clock(clock)
    return nil if clock.blank?
    Time.zone.at(clock.to_i).iso8601
  rescue StandardError
    nil
  end

  def fetch_history(itemids)
    return {} unless connection&.db_enabled?
    Zabbix::HistoryFetcher.new(connection:, itemids: itemids).call
  end

  def interface_item?(item)
    key = item[:key]&.downcase
    metadata = item[:metadata] || {}

    key&.include?("net.if") ||
      metadata.values.any? { |value| value.to_s.downcase.include?("if") } ||
      metadata["SNMPINDEX"].present?
  end
end
