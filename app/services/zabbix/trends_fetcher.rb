module Zabbix
  class TrendsFetcher
    def initialize(connection:, itemids:)
      @connection = connection
      @itemids = Array(itemids).map(&:to_s).reject(&:blank?).uniq
    end

    def call
      return [] if @itemids.empty? || !connection.db_enabled?

      database_connection.with_client do |client, adapter|
        fetch_trends(client, adapter, "trends") + fetch_trends(client, adapter, "trends_uint")
      end
    end

    private

    def fetch_trends(client, adapter, table)
      rows = if adapter == :postgresql
        client.exec_params(postgresql_sql(table), [ @itemids ])
      else
        statement = client.prepare(mysql_sql(table))
        begin
          statement.execute(@itemids.join(",")).to_a
        ensure
          statement&.close
        end
      end

      rows.to_a
    end

    def postgresql_sql(table)
      <<~SQL.squish
        SELECT itemid, clock, num, value_min, value_avg, value_max
        FROM (
          SELECT
            itemid::text AS itemid,
            clock::text AS clock,
            num::text AS num,
            value_min::text AS value_min,
            value_avg::text AS value_avg,
            value_max::text AS value_max,
            ROW_NUMBER() OVER (PARTITION BY itemid ORDER BY clock DESC) AS rn
          FROM #{table}
          WHERE itemid = ANY($1::text[])
        ) sub
        WHERE rn = 1
      SQL
    end

    def mysql_sql(table)
      <<~SQL.squish
        SELECT t.itemid, t.clock, t.num, t.value_min, t.value_avg, t.value_max
        FROM #{table} t
        INNER JOIN (
          SELECT itemid, MAX(clock) AS clock
          FROM #{table}
          WHERE FIND_IN_SET(itemid, ?)
          GROUP BY itemid
        ) latest ON latest.itemid = t.itemid AND latest.clock = t.clock
      SQL
    end

    def database_connection
      @database_connection ||= Zabbix::DatabaseConnection.new(connection: connection)
    end

    def connection
      @connection
    end
  end
end
