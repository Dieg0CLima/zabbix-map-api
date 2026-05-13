module Zabbix
  class DatabaseHostDetailsFetcher
    class Error < StandardError; end
    class UnsupportedAdapterError < Error; end
    class NotFoundError < Error; end

    def initialize(connection:, hostid:)
      @connection = connection
      @hostid = hostid.to_s.strip
    end

    def call
      database_connection.with_client do |client, adapter|
        host_row = fetch_host_row(client, adapter)
        raise NotFoundError, "Host not found" if host_row.blank?

        {
          hostid: host_row["hostid"].to_s,
          host: host_row["host"],
          name: host_row["name"],
          status: host_row["status"].to_s,
          available: normalize_available(host_row["available"]),
          interfaces: fetch_interfaces(client, adapter),
          metadata: {
            host: host_row["host"],
            inventory: build_inventory(host_row),
            groups: fetch_groups(client, adapter),
            templates: fetch_templates(client, adapter)
          }.compact
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

    def fetch_host_row(client, adapter)
      if adapter == :postgresql
        client.exec_params(postgresql_host_sql, [ @hostid ]).first
      else
        statement = client.prepare(mysql_host_sql)
        begin
          statement.execute(@hostid).first
        ensure
          statement&.close
        end
      end
    end

    def fetch_interfaces(client, adapter)
      rows = query_rows(client, adapter, postgresql_interfaces_sql, mysql_interfaces_sql)
      rows.map do |row|
        {
          ip: row["ip"].presence || row["dns"].to_s,
          dns: row["dns"].to_s,
          type: row["type"].to_s,
          main: row["main"].to_s == "1"
        }
      end
    end

    def fetch_groups(client, adapter)
      rows = query_rows(client, adapter, postgresql_groups_sql, mysql_groups_sql)
      rows.map do |row|
        {
          groupid: row["groupid"].to_s,
          name: row["name"].to_s
        }
      end
    end

    def fetch_templates(client, adapter)
      rows = query_rows(client, adapter, postgresql_templates_sql, mysql_templates_sql)
      rows.map do |row|
        {
          templateid: row["templateid"].to_s,
          name: row["name"].to_s
        }
      end
    end

    def query_rows(client, adapter, pg_sql, mysql_sql)
      if adapter == :postgresql
        client.exec_params(pg_sql, [ @hostid ]).to_a
      else
        statement = client.prepare(mysql_sql)
        begin
          statement.execute(@hostid).to_a
        ensure
          statement&.close
        end
      end
    end

    def build_inventory(row)
      inventory = {
        vendor: row["vendor"].presence || row["vendor_name"].presence,
        model: row["model"].presence || row["model_name"].presence
      }.compact
      inventory.presence
    end

    def normalize_available(value)
      value.to_s == "1" || value == true
    end

    def postgresql_host_sql
      <<~SQL.squish
        SELECT
          h.hostid::text AS hostid,
          h.host,
          h.name,
          h.status::text AS status,
          CASE WHEN EXISTS (
            SELECT 1 FROM interface i
            WHERE i.hostid = h.hostid AND i.available = 1
          ) THEN '1' ELSE '0' END AS available,
          hi.vendor,
          hi.model,
          hi.name AS vendor_name,
          hi.model AS model_name
        FROM hosts h
        LEFT JOIN host_inventory hi ON hi.hostid = h.hostid
        WHERE h.hostid::text = $1
        LIMIT 1
      SQL
    end

    def mysql_host_sql
      <<~SQL.squish
        SELECT
          CAST(h.hostid AS CHAR) AS hostid,
          h.host,
          h.name,
          CAST(h.status AS CHAR) AS status,
          CASE WHEN EXISTS (
            SELECT 1 FROM interface i
            WHERE i.hostid = h.hostid AND i.available = 1
          ) THEN '1' ELSE '0' END AS available,
          hi.vendor,
          hi.model,
          hi.name AS vendor_name,
          hi.model AS model_name
        FROM hosts h
        LEFT JOIN host_inventory hi ON hi.hostid = h.hostid
        WHERE CAST(h.hostid AS CHAR) = ?
        LIMIT 1
      SQL
    end

    def postgresql_interfaces_sql
      <<~SQL.squish
        SELECT
          ip,
          dns,
          type::text AS type,
          main::text AS main
        FROM interface
        WHERE hostid::text = $1
        ORDER BY main DESC, interfaceid ASC
      SQL
    end

    def mysql_interfaces_sql
      <<~SQL.squish
        SELECT
          ip,
          dns,
          CAST(type AS CHAR) AS type,
          CAST(main AS CHAR) AS main
        FROM interface
        WHERE CAST(hostid AS CHAR) = ?
        ORDER BY main DESC, interfaceid ASC
      SQL
    end

    def postgresql_groups_sql
      <<~SQL.squish
        SELECT
          g.groupid::text AS groupid,
          g.name
        FROM hosts_groups hg
        INNER JOIN hstgrp g ON g.groupid = hg.groupid
        WHERE hg.hostid::text = $1
        ORDER BY g.name
      SQL
    end

    def mysql_groups_sql
      <<~SQL.squish
        SELECT
          CAST(g.groupid AS CHAR) AS groupid,
          g.name
        FROM hosts_groups hg
        INNER JOIN hstgrp g ON g.groupid = hg.groupid
        WHERE CAST(hg.hostid AS CHAR) = ?
        ORDER BY g.name
      SQL
    end

    def postgresql_templates_sql
      <<~SQL.squish
        SELECT
          t.templateid::text AS templateid,
          t.name
        FROM hosts_templates ht
        INNER JOIN hosts t ON t.hostid = ht.templateid
        WHERE ht.hostid::text = $1
        ORDER BY t.name
      SQL
    end

    def mysql_templates_sql
      <<~SQL.squish
        SELECT
          CAST(t.templateid AS CHAR) AS templateid,
          t.name
        FROM hosts_templates ht
        INNER JOIN hosts t ON t.hostid = ht.templateid
        WHERE CAST(ht.hostid AS CHAR) = ?
        ORDER BY t.name
      SQL
    end
  end
end
