class Zabbix::Observability::BaseFetch
  attr_reader :device

  def initialize(device:, cache: Zabbix::Observability::Cache.new, client_class: Zabbix::Client)
    @device = device
    @cache = cache
    @client_class = client_class
  end

  private

  def with_cache(scope, &block)
    @cache.fetch(device:, scope:, &block)
  end

  def host_id
    device.zabbix_host_id.to_s.presence
  end

  def connection
    @connection ||= device.zabbix_connection
  end

  def client
    @client ||= if @client_class.respond_to?(:call) && !@client_class.respond_to?(:new)
      @client_class.call(connection:)
    else
      @client_class.new(connection:)
    end
  end

  def observability_available?
    connection.present? && host_id.present?
  end

  def api_available?
    observability_available? && connection.api_enabled?
  end

  def database_available?
    observability_available? && connection.db_enabled?
  end

  def unavailable_payload(data = nil)
    {
      status: "unknown",
      zabbix_unavailable: true,
      data:
    }.compact
  end

  def safe_fetch(default:)
    return default unless observability_available?

    yield
  rescue Zabbix::Client::Error, Zabbix::DatabaseConnection::Error, Zabbix::DatabaseItemsFetcher::Error, Zabbix::DatabaseProblemsFetcher::Error, Zabbix::DatabaseHostDetailsFetcher::Error, Timeout::Error => e
    Rails.logger.warn("[Zabbix::Observability] #{self.class.name} failed for device=#{device.id}: #{e.class}: #{e.message}")
    default.merge(zabbix_unavailable: true)
  end

  def parse_time(value)
    Time.zone.at(value.to_i).utc.iso8601
  end

  def severity_name(value)
    {
      0 => "not_classified",
      1 => "information",
      2 => "warning",
      3 => "average",
      4 => "high",
      5 => "disaster"
    }.fetch(value.to_i, "unknown")
  end
end
