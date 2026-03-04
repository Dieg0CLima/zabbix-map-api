class ZabbixConnections::Destroy
  def initialize(connection:)
    @connection = connection
  end

  def call
    @connection.destroy!
  end
end
