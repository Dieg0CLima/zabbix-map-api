require "digest"

module Zabbix
  class HistoryCache
    DEFAULT_TTL   = 60.seconds
    WRITEBACK_TTL = 30.minutes  # how often to flush live values back to zabbix_items
    FAILURE_TTL   = 60.seconds  # how long to skip retries after a DB failure

    def initialize(connection:, itemids:, expires_in: DEFAULT_TTL, value_type_map: nil)
      @connection     = connection
      @itemids        = Array(itemids).map(&:to_s).reject(&:blank?).uniq
      @expires_in     = expires_in
      @value_type_map = value_type_map
    end

    def fetch
      return {} if itemids.empty? || !connection&.db_enabled?

      # Short-circuit if the DB was recently unreachable — serve local columns instead.
      return {} if Rails.cache.exist?(failure_key)

      fetched_fresh = false

      result = Rails.cache.fetch(cache_key, expires_in: expires_in, race_condition_ttl: 5) do
        fetched_fresh = true
        vtype_map = @value_type_map || resolve_value_type_map
        Zabbix::HistoryFetcher.new(connection: connection, itemids: itemids, value_type_map: vtype_map).call
      end

      # Write back to zabbix_items at a lower frequency so the model columns
      # serve as a meaningful fallback when the Zabbix DB is unreachable.
      writeback_async(result) if fetched_fresh && result.present?

      result
    rescue StandardError => error
      Rails.logger.warn { "Zabbix history cache miss (#{connection.id}): #{error.class}: #{error.message}" }
      Rails.cache.write(failure_key, true, expires_in: FAILURE_TTL)
      {}
    end

    private

    attr_reader :connection, :itemids, :expires_in

    # Resolves { "itemid" => "value_type" } from local zabbix_items — single
    # indexed query, avoids querying all Zabbix history tables unnecessarily.
    def resolve_value_type_map
      Zabbix::Item
        .where(itemid: itemids, zabbix_connection_id: connection.id)
        .pluck(:itemid, :value_type)
        .each_with_object({}) { |(itemid, vt), h| h[itemid.to_s] = vt.to_s }
    end

    def cache_key
      items_signature = Digest::SHA1.hexdigest(itemids.sort.join(","))
      "zabbix_history_cache:connection:#{connection.id}:items:#{items_signature}"
    end

    def failure_key
      "zabbix_history_failure:connection:#{connection.id}"
    end

    def writeback_key
      "zabbix_history_writeback:connection:#{connection.id}:items:#{Digest::SHA1.hexdigest(itemids.sort.join(","))}"
    end

    def writeback_async(history)
      return if Rails.cache.exist?(writeback_key)

      Rails.cache.write(writeback_key, true, expires_in: WRITEBACK_TTL)

      updates = history.filter_map do |itemid, entry|
        clock_value = entry["clock"]&.to_i
        next unless clock_value&.positive?

        [ itemid, entry["value"].to_s, Time.zone.at(clock_value) ]
      end

      return if updates.empty?

      conn_id = connection.id

      # Fire-and-forget — uses a fresh connection from the pool.
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          writeback_bulk(conn_id, updates)
        end
      rescue StandardError => e
        Rails.logger.debug { "HistoryCache writeback error: #{e.message}" }
      end
    end

    # Single UPDATE with bind parameters — one query regardless of item count.
    def writeback_bulk(conn_id, updates)
      return if updates.empty?

      connection = Zabbix::Item.connection
      updates.each_slice(200) do |batch|
        statement = build_writeback_statement(connection, conn_id, batch)
        connection.exec_update(statement[:sql], "ZabbixHistoryCache#writeback_bulk", statement[:binds])
      end
    rescue StandardError => e
      Rails.logger.debug { "HistoryCache writeback_bulk error: #{e.message}" }
    end

    def build_writeback_statement(connection, conn_id, updates)
      itemids = updates.map(&:first)
      values_placeholders = updates.map { "(?, ?, ?)" }.join(", ")
      id_placeholders = ([ "?" ] * itemids.length).join(", ")

      sql = <<~SQL.squish
        UPDATE zabbix_items AS zi
        SET lastvalue = src.lastvalue,
            lastclock = src.lastclock
        FROM (VALUES #{values_placeholders}) AS src(itemid, lastvalue, lastclock)
        WHERE zi.zabbix_connection_id = ?
          AND zi.itemid = src.itemid
          AND zi.itemid IN (#{id_placeholders})
      SQL

      bind_values = updates.flat_map { |itemid, value, clock| [ itemid.to_s, value.to_s, clock ] }
      bind_values << conn_id
      bind_values.concat(itemids)

      {
        sql: sql,
        binds: build_binds(connection, bind_values)
      }
    end

    def build_binds(connection, values)
      values.map do |value|
        type = if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
                 ActiveRecord::Type::DateTime.new
        else
                 ActiveRecord::Type::Value.new
        end

        ActiveRecord::Relation::QueryAttribute.new(nil, value, type)
      end
    end
  end
end
