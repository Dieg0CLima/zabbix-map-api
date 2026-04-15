class ZabbixItems::SelectedHistoryFetcher
  Result = Struct.new(:items, :meta, keyword_init: true)

  def initialize(connection:, itemids:)
    @connection = connection
    @itemids    = Array(itemids).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def call
    return Result.new(items: [], meta: meta_for([])) if @itemids.empty? || !connection.db_enabled?

    history = Zabbix::HistoryCache.new(connection: connection, itemids: @itemids).fetch
    return Result.new(items: [], meta: meta_for([])) if history.blank?

    metadata = fetch_items_metadata

    items = @itemids.each_with_object([]) do |itemid, memo|
      next unless (entry = history[itemid])

      memo << format_entry(itemid, entry, metadata[itemid])
    end

    Result.new(items: items, meta: meta_for(items))
  end

  private

  attr_reader :connection

  def fetch_items_metadata
    connection.zabbix_items
              .where(itemid: @itemids)
              .pluck(:itemid, :units, :value_type, :key_)
              .each_with_object({}) do |(itemid, units, value_type, key_), memo|
      memo[itemid] = { units: units, value_type: value_type, key: key_ }
    end
  end

  def format_entry(itemid, entry, meta)
    units      = meta&.dig(:units)
    value_type = meta&.dig(:value_type)
    key        = meta&.dig(:key)

    {
      itemid:        itemid,
      clock:         entry["clock"],
      ns:            entry["ns"],
      value:         entry["value"],
      clock_iso:     format_clock(entry["clock"]),
      units:         units,
      value_type:    value_type,
      display_value: Zabbix::MetricFormatter.display_value(
        entry["value"], units: units, value_type: value_type, key: key
      ),
      lastvalue:  entry["value"],
      lastclock:  entry["clock"],
      lastns:     entry["ns"]
    }
  end

  def format_clock(clock)
    return nil if clock.blank?

    Time.zone.at(clock.to_i).iso8601
  rescue StandardError
    nil
  end

  def meta_for(items)
    {
      connection_id: connection.id,
      count:         items.size,
      source:        connection.db_enabled? ? "database" : "cache",
      itemids:       @itemids
    }
  end
end
