module ZabbixConnections
  class PayloadBuilder
    def initialize(connection:)
      @connection = connection
    end

    def call
      {
        id: @connection.id,
        name: @connection.name,
        status: @connection.status,
        base_url: @connection.base_url,
        default_connection: @connection.default_connection,
        connection_mode: @connection.connection_mode,
        db_adapter: @connection.db_adapter,
        db_host: @connection.db_host,
        db_port: @connection.db_port,
        db_name: @connection.db_name,
        db_username: @connection.db_username,
        metadata: @connection.metadata,
        last_synced_at: @connection.last_synced_at,
        secrets: {
          has_db_password: @connection.attributes_before_type_cast["db_password"].present?,
          has_api_token: @connection.attributes_before_type_cast["api_token"].present?
        }
      }
    end
  end
end
