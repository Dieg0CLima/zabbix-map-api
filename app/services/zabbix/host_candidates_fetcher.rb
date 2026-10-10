module Zabbix
  # Read-only lookup of Zabbix hosts that have an interface with the exact IP.
  # Returns an array of Zabbix::HostPayloadBuilder#details_payload hashes.
  class HostCandidatesFetcher
    MAX_LIMIT = 20

    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end

    TransientHost = Struct.new(:hostid, :name, :status, :available, :interfaces, :metadata, keyword_init: true)

    def initialize(connection:, ip:, limit: MAX_LIMIT)
      @connection = connection
      @ip = ip.to_s.strip
      @limit = normalize_limit(limit)
    end

    def call
      hostids.filter_map { |hostid| details_payload(hostid) }
    rescue Zabbix::DatabaseConnection::UnsupportedAdapterError, Zabbix::DatabaseHostDetailsFetcher::UnsupportedAdapterError => e
      raise UnsupportedAdapterError, e.message
    rescue Zabbix::DatabaseConnection::Error, Zabbix::DatabaseHostDetailsFetcher::Error => e
      raise Error, e.message
    end

    private

    def hostids
      rows = []

      database_connection.with_client do |client, adapter|
        rows = if adapter == :postgresql
          client.exec_params(postgresql_sql, [ @ip, @limit ]).to_a
        else
          statement = client.prepare(mysql_sql)
          begin
            statement.execute(@ip, @ip, @limit).to_a
          ensure
            statement&.close
          end
        end
      end

      rows.map { |row| row["hostid"].to_s }
    end

    def details_payload(hostid)
      details = Zabbix::DatabaseHostDetailsFetcher.new(connection: @connection, hostid: hostid).call
      host = TransientHost.new(**details.slice(:hostid, :name, :status, :available, :interfaces, :metadata))
      Zabbix::HostPayloadBuilder.new(host: host).details_payload
    rescue Zabbix::DatabaseHostDetailsFetcher::NotFoundError
      nil
    end

    def database_connection
      @database_connection ||= Zabbix::DatabaseConnection.new(connection: @connection)
    end

    def postgresql_sql
      <<~SQL.squish
        SELECT h.hostid::text AS hostid
        FROM hosts h
        WHERE h.status <> 3
          AND EXISTS (SELECT 1 FROM interface i WHERE i.hostid = h.hostid AND i.ip = $1)
        ORDER BY
          (EXISTS (SELECT 1 FROM interface m WHERE m.hostid = h.hostid AND m.ip = $1 AND m.main = 1)) DESC,
          h.name, h.hostid
        LIMIT $2
      SQL
    end

    def mysql_sql
      <<~SQL.squish
        SELECT CAST(h.hostid AS CHAR) AS hostid
        FROM hosts h
        WHERE h.status <> 3
          AND EXISTS (SELECT 1 FROM interface i WHERE i.hostid = h.hostid AND i.ip = ?)
        ORDER BY
          (EXISTS (SELECT 1 FROM interface m WHERE m.hostid = h.hostid AND m.ip = ? AND m.main = 1)) DESC,
          h.name, h.hostid
        LIMIT ?
      SQL
    end

    def normalize_limit(limit)
      value = limit.to_i
      value = MAX_LIMIT if value <= 0
      [ value, MAX_LIMIT ].min
    end
  end
end
