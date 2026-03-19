module Zabbix
  class DatabaseItemsFetcher
    DEFAULT_LIMIT = 200
    MAX_LIMIT = 1_000

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    def initialize(connection:, hostid: nil, limit: nil, include_tags: false)
      @connection = connection
      @hostid = hostid.presence
      @limit = normalize_limit(limit)
      @include_tags = include_tags
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

      normalized = rows.map { |row| normalize_row(row) }
      attach_tags!(normalized) if @include_tags
      normalized
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
          i.prevvalue::text AS prevvalue,
          i.lastclock::text AS lastclock,
          i.description,
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
          CAST(i.prevvalue AS CHAR) AS prevvalue,
          CAST(i.lastclock AS CHAR) AS lastclock,
          i.description,
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
        prevvalue: row["prevvalue"],
        lastclock: parse_lastclock(row["lastclock"]),
        description: row["description"],
        tags: [],
        host: {
          hostid: row["hostid"],
          name: row["host"]
        }
      }
    end



    def attach_tags!(items)
      return if items.empty?

      tags_by_item = {}

      begin
        database_connection.with_client do |client, adapter|
          rows = if adapter == :postgresql
            client.exec_params(postgresql_tags_sql(items.length), items.map { |item| item[:itemid] }).to_a
          else
            statement = client.prepare(mysql_tags_sql(items.length))
            begin
              statement.execute(*items.map { |item| item[:itemid] }).to_a
            ensure
              statement&.close
            end
          end

          rows.each do |row|
            itemid = row["itemid"].to_s
            tags_by_item[itemid] ||= []
            tags_by_item[itemid] << { tag: row["tag"].to_s, value: row["value"].to_s }
          end
        end
      rescue Zabbix::DatabaseConnection::Error => e
        Rails.logger.warn("[Zabbix::DatabaseItemsFetcher] unable to load item tags: #{e.message}")
      end

      items.each do |item|
        item[:tags] = tags_by_item[item[:itemid].to_s] || []
      end
    end

    def postgresql_tags_sql(count)
      placeholders = (1..count).map { |index| "$#{index}" }.join(", ")
      <<~SQL.squish
        SELECT
          itemid::text AS itemid,
          tag,
          value
        FROM item_tag
        WHERE itemid IN (#{placeholders})
        ORDER BY itemid, tag, value
      SQL
    end

    def mysql_tags_sql(count)
      placeholders = (["?"] * count).join(", ")
      <<~SQL.squish
        SELECT
          CAST(itemid AS CHAR) AS itemid,
          tag,
          value
        FROM item_tag
        WHERE itemid IN (#{placeholders})
        ORDER BY itemid, tag, value
      SQL
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
