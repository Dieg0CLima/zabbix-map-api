module Zabbix
  class DatabaseHostsFetcher
    DEFAULT_LIMIT = 200
    MAX_LIMIT = 1_000

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:, limit: nil)
      @connection = connection
      @limit = normalize_limit(limit)
    end

    def call
      rows = []

      database_connection.with_client do |client, adapter|
        rows = if adapter == :postgresql
          client.exec_params(postgresql_sql, [@limit]).to_a
        else
          statement = client.prepare(mysql_sql)
          begin
            statement.execute(@limit).to_a
          ensure
            statement&.close
          end
        end
      end

      rows.map { |row| normalize_row(row) }
    rescue Zabbix::DatabaseConnection::UnsupportedAdapterError => e
      raise UnsupportedAdapterError, e.message
    rescue Zabbix::DatabaseConnection::Error => e
      raise Error, e.message
    end

    private

    def database_connection
      @database_connection ||= Zabbix::DatabaseConnection.new(connection: @connection)
    end

    def postgresql_sql
      <<~SQL.squish
        SELECT
          h.hostid::text AS hostid,
          h.host,
          h.name,
          h.status::text AS status,
          h.available::text AS available
        FROM hosts h
        ORDER BY h.hostid
        LIMIT $1
      SQL
    end

    def mysql_sql
      <<~SQL.squish
        SELECT
          CAST(h.hostid AS CHAR) AS hostid,
          h.host,
          h.name,
          CAST(h.status AS CHAR) AS status,
          CAST(h.available AS CHAR) AS available
        FROM hosts h
        ORDER BY h.hostid
        LIMIT ?
      SQL
    end

    def normalize_row(row)
      {
        hostid: row["hostid"],
        host: row["host"],
        name: row["name"],
        status: row["status"],
        available: row["available"]
      }
    end

    def normalize_limit(limit)
      value = limit.to_i
      value = DEFAULT_LIMIT if value <= 0
      [value, MAX_LIMIT].min
    end
  end
end
