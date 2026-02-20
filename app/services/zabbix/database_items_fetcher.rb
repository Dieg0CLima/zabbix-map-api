module Zabbix
  class DatabaseItemsFetcher
    DEFAULT_LIMIT = 200
    MAX_LIMIT = 1_000

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:, hostid: nil, limit: nil)
      @connection = connection
      @hostid = hostid.presence
      @limit = normalize_limit(limit)
    end

    def call
      rows = []

      database_connection.with_client do |client, adapter|
        rows = if adapter == :postgresql
          client.exec_params(postgresql_sql, sql_params).to_a
        else
          statement = client.prepare(mysql_sql)
          begin
            statement.execute(*sql_params).to_a
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
          i.itemid::text AS itemid,
          i.name,
          i.key_ AS key_,
          i.value_type::text AS value_type,
          i.units,
          i.status::text AS status,
          i.state::text AS state,
          i.lastvalue::text AS lastvalue,
          i.lastclock::text AS lastclock,
          h.hostid::text AS hostid,
          h.host
        FROM items i
        LEFT JOIN hosts h ON h.hostid = i.hostid
        #{"WHERE i.hostid = $1" if @hostid.present?}
        ORDER BY i.itemid
        LIMIT $#{@hostid.present? ? 2 : 1}
      SQL
    end

    def mysql_sql
      <<~SQL.squish
        SELECT
          CAST(i.itemid AS CHAR) AS itemid,
          i.name,
          i.key_ AS key_,
          CAST(i.value_type AS CHAR) AS value_type,
          i.units,
          CAST(i.status AS CHAR) AS status,
          CAST(i.state AS CHAR) AS state,
          CAST(i.lastvalue AS CHAR) AS lastvalue,
          CAST(i.lastclock AS CHAR) AS lastclock,
          CAST(h.hostid AS CHAR) AS hostid,
          h.host
        FROM items i
        LEFT JOIN hosts h ON h.hostid = i.hostid
        #{"WHERE i.hostid = ?" if @hostid.present?}
        ORDER BY i.itemid
        LIMIT ?
      SQL
    end

    def sql_params
      params = []
      params << @hostid if @hostid.present?
      params << @limit
      params
    end

    def normalize_row(row)
      {
        itemid: row["itemid"],
        name: row["name"],
        key_: row["key_"],
        value_type: row["value_type"],
        units: row["units"],
        status: row["status"],
        state: row["state"],
        lastvalue: row["lastvalue"],
        lastclock: parse_lastclock(row["lastclock"]),
        host: {
          hostid: row["hostid"],
          name: row["host"]
        }
      }
    end

    def normalize_limit(limit)
      value = limit.to_i
      value = DEFAULT_LIMIT if value <= 0
      [value, MAX_LIMIT].min
    end

    def parse_lastclock(value)
      return if value.blank?

      Time.zone.at(value.to_i)
    end
  end
end
