module Zabbix
  class DatabaseHostsFetcher
    DEFAULT_LIMIT = 500
    MAX_LIMIT = 10_000

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:, limit: nil, search: nil)
      @connection = connection
      @limit = normalize_limit(limit)
      @search = search.to_s.strip
    end

    def call
      rows = []

      database_connection.with_client do |client, adapter|
        rows = if adapter == :postgresql
          client.exec_params(postgresql_sql, [search_term, @limit]).to_a
        else
          statement = client.prepare(mysql_sql)
          begin
            statement.execute(search_term_lower, search_term_lower, search_term, @limit).to_a
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
          h.status::text AS status
        FROM hosts h
        WHERE h.status <> 3
          AND (h.name ILIKE $1 OR h.host ILIKE $1 OR h.hostid::text ILIKE $1)
        ORDER BY h.name_upper NULLS LAST, h.name, h.hostid
        LIMIT $2
      SQL
    end

    def mysql_sql
      <<~SQL.squish
        SELECT
          CAST(h.hostid AS CHAR) AS hostid,
          h.host,
          h.name,
          CAST(h.status AS CHAR) AS status
        FROM hosts h
        WHERE h.status <> 3
          AND (LOWER(h.name) LIKE ? OR LOWER(h.host) LIKE ? OR CAST(h.hostid AS CHAR) LIKE ?)
        ORDER BY h.name_upper, h.name, h.hostid
        LIMIT ?
      SQL
    end

    def normalize_row(row)
      {
        hostid: row["hostid"],
        host: row["host"],
        name: row["name"],
        status: row["status"]
      }
    end

    def search_term
      return "%" if @search.blank?

      "%#{@search}%"
    end

    def search_term_lower
      return "%" if @search.blank?

      "%#{@search.downcase}%"
    end

    def normalize_limit(limit)
      value = limit.to_i
      value = DEFAULT_LIMIT if value <= 0
      [value, MAX_LIMIT].min
    end
  end
end
