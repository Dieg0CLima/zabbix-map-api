class ZabbixItems::SummaryFetcher
  DEFAULT_LIMIT = 500
  MAX_LIMIT = 2_000

  Result = Struct.new(:items, :meta, keyword_init: true)

  def initialize(connection:, hostid: nil, zabbix_host_id: nil, limit: nil)
    @connection = connection
    @hostid = hostid.to_s.strip.presence
    @zabbix_host_id = zabbix_host_id.to_s.strip.presence
    @limit = normalize_limit(limit)
  end

  def call
    rows = fetch_rows
    items = rows.map { |row| build_item(row) }

    Result.new(items: items, meta: meta_for(items))
  end

  private

  attr_reader :connection, :hostid, :zabbix_host_id, :limit

  def fetch_rows
    if connection.db_enabled?
      rows = Zabbix::DatabaseItemsFetcher.new(connection: connection, hostid: resolved_hostid, limit: limit).call
      enrich_with_local_ids(rows)
    else
      return [] unless valid_cache_host?

      fetch_cached_items
    end
  end

  def fetch_cached_items
    scope = connection.zabbix_items.includes(:host).order(:key_)
    scope = scope.where(zabbix_host_id: host_record.id) if host_record
    scope = scope.limit(limit) if limit.positive?

    scope.map do |item|
      build_row_from_cached(item)
    end
  end

  def build_row_from_cached(item)
    {
      "itemid" => item.itemid,
      "local_id" => item.id,
      "name" => item.name,
      "key_" => item.key_,
      "value_type" => item.value_type,
      "units" => item.units,
      "status" => item.status,
      "state" => item.state,
      "metadata" => item.metadata,
      "lastvalue" => item.lastvalue,
      "lastclock" => item.lastclock&.to_i,
      "host" => {
        "hostid" => item.host&.hostid,
        "name" => item.host&.name
      }.compact
    }
  end

  def enrich_with_local_ids(rows)
    return rows if rows.empty?

    itemids = rows.map { |r| r[:itemid].to_s }
    local_map = connection.zabbix_items.where(itemid: itemids).pluck(:itemid, :id).to_h
    rows.map { |r| r.merge(local_id: local_map[r[:itemid].to_s]) }
  end

  def build_item(row)
    data = row.with_indifferent_access
    host_data = data["host"] || {}

    {
      itemid: data["itemid"],
      local_id: data["local_id"],
      name: data["name"],
      key: data["key_"],
      value_type: data["value_type"],
      units: data["units"],
      status: normalize_status(data["status"]),
      state: data["state"],
      metadata: (data["metadata"] || {}).dup,
      host: {
        hostid: host_data["hostid"],
        name: host_data["name"]
      }.compact,
      lastvalue: data["lastvalue"],
      lastclock: normalize_clock(data["lastclock"])
    }
  end

  def normalize_clock(value)
    return if value.nil?

    value.to_s
  end

  def normalize_status(value)
    value.to_s
  end

  def host_record
    return @host_record if defined?(@host_record)

    @host_record = if zabbix_host_id.present?
      connection.zabbix_hosts.find_by(id: zabbix_host_id)
    elsif hostid.present?
      connection.zabbix_hosts.find_by(hostid: hostid)
    end
  end

  def valid_cache_host?
    return true if hostid.blank? && zabbix_host_id.blank?

    host_record.present?
  end

  def resolved_hostid
    hostid.presence || host_record&.hostid
  end

  def meta_for(items)
    {
      connection_id: connection.id,
      hostid: resolved_hostid,
      zabbix_host_id: zabbix_host_id,
      limit: limit,
      count: items.size,
      source: connection.db_enabled? ? "database" : "cache"
    }.compact
  end

  def normalize_limit(value)
    number = value.to_i
    number = DEFAULT_LIMIT if number <= 0
    [number, MAX_LIMIT].min
  end
end
