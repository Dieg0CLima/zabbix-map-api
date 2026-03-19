class Zabbix::HostDetailsFetcher
  class Error < StandardError; end
  class UnsupportedAdapterError < Error; end

  def initialize(connection:, hostid:)
    @connection = connection
    @hostid = hostid.to_s.strip
  end

  def call
    Zabbix::HostPayloadBuilder.new(host: host_record).details_payload
  rescue Zabbix::DatabaseHostDetailsFetcher::UnsupportedAdapterError => e
    raise UnsupportedAdapterError, e.message
  rescue Zabbix::DatabaseHostDetailsFetcher::NotFoundError, Zabbix::DatabaseHostDetailsFetcher::Error => e
    raise Error, e.message
  end

  def reference_payload
    payload = call
    {
      hostid: payload[:hostid].to_s,
      name: payload[:name],
      status: payload[:status],
      available: payload[:available],
      interfaces: payload[:interfaces],
      metadata: payload[:metadata]
    }
  end

  private

  def host_record
    return persisted_host if persisted_host.present? && !@connection.db_enabled?
    return build_transient_host(Zabbix::DatabaseHostDetailsFetcher.new(connection: @connection, hostid: @hostid).call) if @connection.db_enabled?

    raise Error, "Host not found" unless persisted_host.present?

    persisted_host
  end

  def persisted_host
    @persisted_host ||= @connection.zabbix_hosts.find_by(hostid: @hostid)
  end

  def build_transient_host(payload)
    Struct.new(:hostid, :name, :status, :available, :interfaces, :metadata, keyword_init: true).new(
      hostid: payload[:hostid],
      name: payload[:name],
      status: payload[:status],
      available: payload[:available],
      interfaces: payload[:interfaces],
      metadata: payload[:metadata]
    )
  end
end
