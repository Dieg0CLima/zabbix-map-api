class ZabbixHosts::ItemsFetcher
  DEFAULT_LIMIT  = 500
  CATALOG_TTL    = 5.minutes
  DB_FAILURE_TTL = 60.seconds

  class Error < StandardError; end

  def initialize(connection:, hostid:, limit: nil, force_refresh: false)
    @connection    = connection
    @hostid        = hostid.to_s.strip
    @limit         = [ limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT, 2_000 ].min
    @force_refresh = force_refresh
  end

  def call
    should_sync = @force_refresh || (catalog_stale? && !db_failed?)
    sync_from_zabbix if should_sync

    build_result(read_local_items)
  end

  private

  # -- Cache helpers ------------------------------------------------------------

  def catalog_cache_key
    "zabbix_items_catalog:conn:#{@connection.id}:host:#{@hostid}"
  end

  def db_failure_key
    "zabbix_items_catalog_failure:conn:#{@connection.id}"
  end

  def catalog_stale?
    !Rails.cache.exist?(catalog_cache_key)
  end

  def db_failed?
    Rails.cache.exist?(db_failure_key)
  end

  def mark_catalog_fresh!
    Rails.cache.write(catalog_cache_key, true, expires_in: CATALOG_TTL)
  end

  def mark_db_failed!
    Rails.cache.write(db_failure_key, true, expires_in: DB_FAILURE_TTL)
  end

  # -- Zabbix sync --------------------------------------------------------------

  def sync_from_zabbix
    raw_items  = fetch_raw_items
    local_host = find_or_create_local_host
    upsert_items(raw_items, local_host) if raw_items.any?
    mark_catalog_fresh!
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    Rails.logger.warn { "ZabbixHosts::ItemsFetcher: DB sync failed (conn=#{@connection.id}): #{e.message}" }
    mark_db_failed!
  end

  def fetch_raw_items
    if @connection.db_enabled?
      Zabbix::DatabaseItemsFetcher.new(connection: @connection, hostid: @hostid, limit: @limit).call
    else
      @connection.zabbix_items
                 .includes(:host)
                 .where(zabbix_hosts: { hostid: @hostid })
                 .order(:name)
                 .limit(@limit)
                 .map do |item|
                   {
                     itemid:     item.itemid,
                     name:       item.name,
                     key_:       item.key_,
                     value_type: item.value_type,
                     units:      item.units,
                     status:     item.status
                   }
                 end
    end
  end

  def find_local_host
    @local_host ||= @connection.zabbix_hosts.find_by(hostid: @hostid)
  end

  def find_or_create_local_host
    find_local_host || @connection.zabbix_hosts.create!(
      hostid: @hostid,
      name:   "Host #{@hostid}"
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    @connection.zabbix_hosts.find_by(hostid: @hostid)
  end

  def upsert_items(raw_items, local_host)
    now = Time.current
    records = raw_items.map do |raw|
      {
        itemid:               raw[:itemid].to_s,
        name:                 raw[:name].to_s,
        key_:                 raw[:key_].to_s,
        value_type:           raw[:value_type].to_s,
        units:                raw[:units].to_s,
        status:               raw[:status].to_s,
        zabbix_host_id:       local_host&.id,
        zabbix_connection_id: @connection.id,
        created_at:           now,
        updated_at:           now
      }
    end

    Zabbix::Item.upsert_all(
      records,
      unique_by:   %i[itemid zabbix_connection_id],
      update_only: %i[name key_ value_type units status zabbix_host_id]
    )
  rescue ActiveRecord::RecordInvalid
    # swallow -- local read will still return whatever was persisted before
  end

  # -- Local DB read ------------------------------------------------------------

  def read_local_items
    host = find_local_host

    scope = if host
      # Prefer items linked to the specific host; fall through to orphaned items
      # when none are associated yet (zabbix_host_id was nil at upsert time).
      linked = @connection.zabbix_items.where(zabbix_host_id: host.id)
      linked.exists? ? linked : @connection.zabbix_items.where(zabbix_host_id: nil)
    else
      @connection.zabbix_items.where(zabbix_host_id: nil)
    end

    scope.limit(@limit)
  end

  def build_result(items)
    items.sort_by { |i| i.name.to_s.downcase }.map do |item|
      {
        value:      item.id,
        label:      "#{item.name} (#{item.key_})",
        name:       item.name,
        key:        item.key_,
        itemid:     item.itemid,
        units:      item.units,
        value_type: item.value_type
      }
    end
  end
end
