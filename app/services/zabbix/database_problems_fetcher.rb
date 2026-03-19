module Zabbix
  class DatabaseProblemsFetcher
    DEFAULT_LIMIT = 20

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:, hostid:, limit: DEFAULT_LIMIT)
      @connection = connection
      @hostid = hostid.to_s
      @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
    end

    def call
      rows = []

      database_connection.with_client do |client, adapter|
        rows = if adapter == :postgresql
          client.exec_params(postgresql_sql, [@hostid, @limit]).to_a
        else
          statement = client.prepare(mysql_sql)
          begin
            statement.execute(@hostid, @limit).to_a
          ensure
            statement&.close
          end
        end
      end

      rows.map do |row|
        {
          "eventid" => row["eventid"].to_s,
          "name" => row["name"].to_s,
          "severity" => row["severity"].to_s,
          "clock" => row["clock"].to_s,
          "acknowledged" => row["acknowledged"].to_s,
          "value" => "1",
          "r_eventid" => "0"
        }
      end
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
          p.eventid::text AS eventid,
          COALESCE(e.name, t.description, 'Unnamed problem') AS name,
          COALESCE(e.severity::text, t.priority::text, '0') AS severity,
          p.clock::text AS clock,
          COALESCE(e.acknowledged::text, '0') AS acknowledged
        FROM problem p
        LEFT JOIN events e ON e.eventid = p.eventid
        LEFT JOIN triggers t ON t.triggerid = p.objectid
        INNER JOIN functions f ON f.triggerid = t.triggerid
        INNER JOIN items i ON i.itemid = f.itemid
        WHERE i.hostid::text = $1
        ORDER BY p.clock DESC
        LIMIT $2
      SQL
    end

    def mysql_sql
      <<~SQL.squish
        SELECT
          CAST(p.eventid AS CHAR) AS eventid,
          COALESCE(e.name, t.description, 'Unnamed problem') AS name,
          COALESCE(CAST(e.severity AS CHAR), CAST(t.priority AS CHAR), '0') AS severity,
          CAST(p.clock AS CHAR) AS clock,
          COALESCE(CAST(e.acknowledged AS CHAR), '0') AS acknowledged
        FROM problem p
        LEFT JOIN events e ON e.eventid = p.eventid
        LEFT JOIN triggers t ON t.triggerid = p.objectid
        INNER JOIN functions f ON f.triggerid = t.triggerid
        INNER JOIN items i ON i.itemid = f.itemid
        WHERE CAST(i.hostid AS CHAR) = ?
        ORDER BY p.clock DESC
        LIMIT ?
      SQL
    end
  end
end
