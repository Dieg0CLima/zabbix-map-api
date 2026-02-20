require "pg"

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
      validate_adapter!

      rows = if postgresql_adapter?
        fetch_postgresql_rows
      else
        fetch_mysql_rows
      end

      rows.map { |row| normalize_row(row) }
    rescue *database_error_classes => e
      raise Error, e.message
    ensure
      @db_client&.close
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

    def fetch_postgresql_rows
      @db_client = PG.connect(db_config)
      @db_client.exec_params(postgresql_sql, sql_params)
    end

    def fetch_mysql_rows
      @db_client = mysql_client_class.new(symbolize_keys(db_config))
      statement = @db_client.prepare(mysql_sql)
      statement.execute(*sql_params).to_a
    ensure
      statement&.close
    end

    def mysql_client_class
      require "mysql2"
      Mysql2::Client
    rescue LoadError => e
      raise Error, "mysql2 gem is required to query MySQL databases (#{e.message})"
    end

    def db_config
      {
        host: @connection.db_host,
        port: @connection.db_port,
        dbname: @connection.db_name,
        user: @connection.db_username,
        password: @connection.db_password
      }
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

    def database_error_classes
      classes = [PG::Error]
      classes << Mysql2::Error if defined?(Mysql2::Error)
      classes
    end

    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end
  end
end
