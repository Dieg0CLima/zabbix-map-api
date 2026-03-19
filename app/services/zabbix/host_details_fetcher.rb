class Zabbix::HostDetailsFetcher
  class Error < StandardError; end

  def initialize(connection:, hostid:)
    @connection = connection
    @hostid = hostid.to_s.strip
  end

  def call
    host = @connection.zabbix_hosts.find_by(hostid: @hostid)
    raise Error, "Host not found" unless host

    Zabbix::HostPayloadBuilder.new(host:).details_payload
  end
end
