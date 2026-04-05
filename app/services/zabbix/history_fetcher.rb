module Zabbix
  class HistoryFetcher
    HISTORY_TABLES = %w[history history_uint].freeze

    def initialize(connection:, itemids:)
      @connection = connection
      @itemids = Array(itemids).map(&:to_s).reject(&:blank?).uniq
    end

    def call
      return [] if @itemids.empty? || !connection.db_enabled?

      database_connection.with_client do |client, adapter|
        normalize_rows(fetch_history(client, adapter))
      end
    end

    private

    def normalize_rows(rows)
      rows.each_with_object({}) do |row, memo|
        item_key = row["itemid"].to_s
        candidate = {
          "itemid" => item_key,
          "clock" => row["clock"],
          "value" => row["value"],
          "ns" => row["ns"]
        }
        existing = memo[item_key]
        memo[item_key] = candidate if existing.nil? || newer_record?(existing, candidate)
      end
    end

    def newer_record?(current, candidate)
      candidate_clock = candidate["clock"].to_i
      current_clock = current["clock"].to_i
      return true if candidate_clock > current_clock
      return false if candidate_clock < current_clock

      candidate_ns = candidate["ns"].to_i
      current_ns = current["ns"].to_i
      candidate_ns > current_ns
    end

    def fetch_history(client, adapter)
      HISTORY_TABLES.flat_map do |table|
        fetch_history_from_table(client, adapter, table)
      end
    end

    def fetch_history_from_table(client, adapter, table)
      if adapter == :postgresql
        client.exec_params(postgresql_sql(table), [@itemids]).to_a
      else
        statement = client.prepare(mysql_sql(table))
        begin
          statement.execute(@itemids.join(",")).to_a
        ensure
          statement&.close
        end
      end
    end

    def postgresql_sql(table)
      <<~SQL.squish
        SELECT itemid, clock, value, ns
        FROM (
          SELECT
            itemid::text AS itemid,
            clock::text AS clock,
            value::text AS value,
            ns::text AS ns,
            ROW_NUMBER() OVER (PARTITION BY itemid ORDER BY clock DESC, ns DESC) AS rn
          FROM #{table}
          WHERE itemid = ANY($1::text[])
        ) sub
        WHERE rn = 1
      SQL
    end

    def mysql_sql(table)
      <<~SQL.squish
        SELECT h.itemid, h.clock, h.value, h.ns
        FROM #{table} h
        INNER JOIN (
          SELECT itemid, MAX(clock) AS clock
          FROM #{table}
          WHERE FIND_IN_SET(itemid, ?)
          GROUP BY itemid
        ) latest ON latest.itemid = h.itemid AND latest.clock = h.clock
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
