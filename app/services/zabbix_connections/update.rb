class ZabbixConnections::Update
  def initialize(connection:, payload:)
    @connection = connection
    @payload = payload
  end

  def call
    @connection.update!(@payload)
    @connection
  end
end
