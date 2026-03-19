class Zabbix::Observability::Cache
  DEFAULT_TTL = ENV.fetch("ZABBIX_OBSERVABILITY_CACHE_TTL", 30).to_i.seconds

  def initialize(store: Rails.cache, ttl: DEFAULT_TTL)
    @store = store
    @ttl = ttl
  end

  def fetch(device:, scope:)
    @store.fetch(cache_key(device:, scope:), expires_in: @ttl) { yield }
  end

  private

  def cache_key(device:, scope:)
    [
      "zabbix-observability",
      scope,
      "org:#{device.organization_id}",
      "device:#{device.id}",
      "connection:#{device.zabbix_connection_id || 'none'}",
      "host:#{device.zabbix_host_id || 'none'}"
    ].join(":")
  end
end
