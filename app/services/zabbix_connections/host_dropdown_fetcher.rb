class ZabbixConnections::HostDropdownFetcher
  DEFAULT_LIMIT = 5_000
  MAX_LIMIT = 10_000
  EXCLUDED_STATUSES = %w[3].freeze

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

    fetched_hosts.filter_map do |host|
      next if excluded_status?(host[:status])

      transient_host = Struct.new(:hostid, :name, :status, :available, :interfaces, :metadata, keyword_init: true).new(
        hostid: host[:hostid],
        name: host[:name],
        status: host[:status],
        available: host[:available],
        interfaces: host[:interfaces] || [],
        metadata: host[:metadata] || {}
      )
      Zabbix::HostPayloadBuilder.new(host: transient_host).dropdown_payload
    end
  end

  def persisted_dropdown_hosts
    scope = @connection.zabbix_hosts
    scope = scope.where.not(status: EXCLUDED_STATUSES)
    scope = scope.where("name ILIKE :q OR hostid ILIKE :q", q: "%#{@query}%") if @query.present?

    scope.order(:name, :hostid).limit(@limit).map do |host|
      Zabbix::HostPayloadBuilder.new(host:).dropdown_payload
    end
  end

  def fetched_hosts
    Zabbix::DatabaseHostsFetcher.new(connection: @connection, limit: @limit, search: @query).call
  rescue Zabbix::DatabaseHostsFetcher::UnsupportedAdapterError => e
    raise UnsupportedAdapterError, e.message
  rescue Zabbix::DatabaseHostsFetcher::Error => e
    raise Error, e.message
  end

  def normalize_limit(limit)
    value = limit.to_i
    value = DEFAULT_LIMIT if value <= 0
    [value, MAX_LIMIT].min
  end

  def excluded_status?(status)
    EXCLUDED_STATUSES.include?(status.to_s)
  end
end
