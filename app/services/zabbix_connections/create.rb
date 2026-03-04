class ZabbixConnections::Create
  def initialize(organization:, payload:)
    @organization = organization
    @payload = payload
  end

  def call
    connection = @organization.zabbix_connections.new(@payload)
    connection.save!
    connection
  end
end
