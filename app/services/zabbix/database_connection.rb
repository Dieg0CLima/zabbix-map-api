require "pg"

module Zabbix
  class DatabaseConnection
    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:)
      @connection = connection
    end

    def with_client
      validate_adapter!

      if postgresql_adapter?
        client = PG.connect(postgresql_config)
        yield client, :postgresql
      else
        client = mysql_client_class.new(mysql_config)
        yield client, :mysql
      end
    rescue *database_error_classes => e
      raise Error, e.message
    ensure
      client&.close
    end

    private

    def validate_adapter!
      return if postgresql_adapter? || mysql_adapter?

      raise UnsupportedAdapterError, "Only postgresql and mysql adapters are currently supported"
    end

    def postgresql_adapter?
      @connection.db_adapter == "postgresql"
    end

    def mysql_adapter?
      @connection.db_adapter == "mysql"
    end

    def postgresql_config
      {
        host: @connection.db_host,
        port: @connection.db_port,
        dbname: @connection.db_name,
        user: @connection.db_username,
        password: @connection.db_password
      }
    end

    def mysql_config
      {
        host: @connection.db_host,
        port: @connection.db_port,
        database: @connection.db_name,
        username: @connection.db_username,
        password: @connection.db_password
      }
    end

    def mysql_client_class
      require "mysql2"
      Mysql2::Client
    rescue LoadError => e
      raise Error, "mysql2 gem is required to query MySQL databases (#{e.message})"
    end

    def database_error_classes
      classes = [PG::Error]
      classes << Mysql2::Error if defined?(Mysql2::Error)
      classes
    end
  end
end
