module Zabbix
  class HistoryFetcher
    # Maps Zabbix value_type to history table.
    # value_type: 0=float, 1=string, 2=log (skipped — different schema), 3=uint, 4=text
    VALUE_TYPE_TABLE = {
      "0" => "history",
      "1" => "history_str",
      "3" => "history_uint",
      "4" => "history_text"
    }.freeze

    ALL_TABLES = VALUE_TYPE_TABLE.values.uniq.freeze

    def initialize(connection:, itemids:, value_type_map: nil)
      @connection     = connection
      @itemids        = Array(itemids).map(&:to_s).reject(&:blank?).uniq
      # Optional: { "itemid" => "value_type" } — allows routing each item to the
      # correct table instead of querying all tables. When absent, all tables are queried.
      @value_type_map = value_type_map
    end

    def call
      return {} if @itemids.empty? || !connection.db_enabled?

      database_connection.with_client do |client, adapter|
        normalize_rows(fetch_history(client, adapter))
      end
    end

    private

    def normalize_rows(rows)
      rows.each_with_object({}) do |row, memo|
        item_key  = row["itemid"].to_s
        candidate = {
          "itemid" => item_key,
          "clock"  => row["clock"],
          "value"  => row["value"],
          "ns"     => row["ns"]
        }
        existing = memo[item_key]
        memo[item_key] = candidate if existing.nil? || newer_record?(existing, candidate)
      end
    end

    def newer_record?(current, candidate)
      c_clock = candidate["clock"].to_i
      e_clock = current["clock"].to_i
      return true  if c_clock > e_clock
      return false if c_clock < e_clock

      candidate["ns"].to_i > current["ns"].to_i
    end

    # Build a table → itemids mapping so we only query relevant tables.
    def table_itemids_map
      return ALL_TABLES.index_with { @itemids } unless @value_type_map.present?

      map = Hash.new { |h, k| h[k] = [] }
      @itemids.each do |itemid|
        vtype = @value_type_map[itemid].to_s
        table = VALUE_TYPE_TABLE[vtype]
        next unless table

        map[table] << itemid
      end

      # Any itemid with unknown value_type falls back to querying all tables
      unrouted = @itemids - @value_type_map.keys.map(&:to_s)
      if unrouted.any?
        ALL_TABLES.each { |t| map[t] |= unrouted }
      end

      map
    end

    def fetch_history(client, adapter)
      table_itemids_map.flat_map do |table, ids|
        next [] if ids.empty?

        fetch_history_from_table(client, adapter, table, ids)
      end
    end

    def fetch_history_from_table(client, adapter, table, ids)
      if adapter == :postgresql
        client.exec_params(postgresql_sql(table), [ids]).to_a
      else
        client.query(mysql_sql(table, ids)).to_a
      end
    rescue StandardError => e
      Rails.logger.warn { "HistoryFetcher: error querying #{table}: #{e.message}" }
      []
    end

    def postgresql_sql(table)
      <<~SQL.squish
        SELECT itemid, clock, value, ns
        FROM (
          SELECT
            itemid::text     AS itemid,
            clock::text      AS clock,
            value::text      AS value,
            ns::text         AS ns,
            ROW_NUMBER() OVER (PARTITION BY itemid ORDER BY clock DESC, ns DESC) AS rn
          FROM #{table}
          WHERE itemid = ANY($1::bigint[])
        ) sub
        WHERE rn = 1
      SQL
    end

    # IDs are cast to Integer before inlining — safe against injection.
    # Uses IN (...) so MySQL can use the itemid index; avoids FIND_IN_SET
    # which forces a full table scan and loses the connection on large tables.
    # normalize_rows handles ns tie-breaking in Ruby when clock ties occur.
    def mysql_sql(table, ids)
      in_clause = ids.map { |id| Integer(id) }.join(", ")
      <<~SQL.squish
        SELECT h.itemid, h.clock, h.value, h.ns
        FROM #{table} h
        INNER JOIN (
          SELECT itemid, MAX(clock) AS max_clock
          FROM #{table}
          WHERE itemid IN (#{in_clause})
          GROUP BY itemid
        ) latest ON latest.itemid = h.itemid
                AND h.clock = latest.max_clock
      SQL
    end

    def database_connection
      @database_connection ||= Zabbix::DatabaseConnection.new(connection: connection)
    end

    attr_reader :connection
  end
end
