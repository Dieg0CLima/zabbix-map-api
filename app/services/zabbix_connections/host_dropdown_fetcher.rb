class ZabbixConnections::HostDropdownFetcher
  DEFAULT_LIMIT = 5_000
  MAX_LIMIT = 10_000

  class Error < StandardError; end
  class UnsupportedAdapterError < Error; end

  def initialize(connection:, limit: nil, query: nil)
    @connection = connection
    @limit = normalize_limit(limit)
    @query = query.to_s.strip
  end

  def call
    dropdown_hosts.sort_by { |host| [host[:label].to_s.downcase, host[:hostid].to_s] }
  end

  private

  def dropdown_hosts
    return persisted_dropdown_hosts unless @connection.db_enabled?

    fetched_hosts.map do |host|
      {
        value: host[:hostid].to_s,
        label: host[:name].presence || host[:host].to_s,
        hostid: host[:hostid].to_s,
        available: db_status_available?(host[:status])
      }
    end
  end

  def persisted_dropdown_hosts
    scope = @connection.zabbix_hosts
    scope = scope.where("name ILIKE :q OR hostid ILIKE :q", q: "%#{@query}%") if @query.present?

    scope.order(:name, :hostid).limit(@limit).map do |host|
      {
        value: host.hostid.to_s,
        label: host.name,
        hostid: host.hostid.to_s,
        available: persisted_available?(host.available)
      }
    end
  end

  def fetched_hosts
    Zabbix::DatabaseHostsFetcher.new(connection: @connection, limit: @limit, search: @query).call
  rescue Zabbix::DatabaseHostsFetcher::UnsupportedAdapterError => e
    raise UnsupportedAdapterError, e.message
  rescue Zabbix::DatabaseHostsFetcher::Error => e
    raise Error, e.message
  end

  def db_status_available?(status)
    status.to_s == "0"
  end

  def persisted_available?(value)
    return value if value == true || value == false

    normalized = value.to_s.strip.downcase
    normalized.in?(["1", "true", "up", "available", "enabled"])
  end

  def normalize_limit(limit)
    value = limit.to_i
    value = DEFAULT_LIMIT if value <= 0
    [value, MAX_LIMIT].min
  end
end
