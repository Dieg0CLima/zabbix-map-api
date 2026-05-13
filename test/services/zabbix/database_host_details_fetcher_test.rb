require "test_helper"

class Zabbix::DatabaseHostDetailsFetcherTest < ActiveSupport::TestCase
  test "fetches and normalizes host details from postgresql zabbix database" do
    connection = build_connection

    fake_client = FakePgClient.new(
      host_row: {
        "hostid" => "10668",
        "host" => "core-bsb-01",
        "name" => "HOST-CORE-BRASILIA",
        "status" => "0",
        "available" => "1",
        "vendor" => "Huawei",
        "model" => "S5720",
        "vendor_name" => nil,
        "model_name" => nil
      },
      interfaces: [
        { "ip" => "10.0.0.1", "dns" => "", "type" => "2", "main" => "1" }
      ],
      groups: [
        { "groupid" => "4", "name" => "Core" }
      ],
      templates: [
        { "templateid" => "22", "name" => "Base Template" }
      ]
    )

    fake_database_connection = Struct.new(:client) do
      def with_client
        yield(client, :postgresql)
      end
    end.new(fake_client)

    fetcher = Zabbix::DatabaseHostDetailsFetcher.new(connection:, hostid: "10668")

    fetcher.stub(:database_connection, fake_database_connection) do
      payload = fetcher.call

      assert_equal "10668", payload[:hostid]
      assert_equal "HOST-CORE-BRASILIA", payload[:name]
      assert_equal "core-bsb-01", payload[:host]
      assert_equal true, payload[:available]
      assert_equal "Huawei", payload.dig(:metadata, :inventory, :vendor)
      assert_equal "10.0.0.1", payload[:interfaces].first[:ip]
      assert_equal "Core", payload.dig(:metadata, :groups, 0, :name)
    end

  end

  test "raises not found when host is absent in zabbix database" do
    connection = build_connection
    fake_client = FakePgClient.new(host_row: nil, interfaces: [], groups: [], templates: [])

    fake_database_connection = Struct.new(:client) do
      def with_client
        yield(client, :postgresql)
      end
    end.new(fake_client)

    fetcher = Zabbix::DatabaseHostDetailsFetcher.new(connection:, hostid: "99999")

    fetcher.stub(:database_connection, fake_database_connection) do
      assert_raises(Zabbix::DatabaseHostDetailsFetcher::NotFoundError) { fetcher.call }
    end

  end

  private

  def build_connection(db_adapter: "postgresql")
    ZabbixConnection.new(
      name: "Zabbix Primario",
      organization: Organization.new(name: "Org Test"),
      connection_mode: "database",
      db_adapter:,
      db_host: "127.0.0.1",
      db_port: 5432,
      db_name: "zabbix",
      db_username: "zabbix",
      db_password: "secret"
    )
  end

  class FakePgClient
    def initialize(host_row:, interfaces:, groups:, templates:)
      @host_row = host_row
      @interfaces = interfaces
      @groups = groups
      @templates = templates
    end

    def exec_params(sql, _params)
      case sql
      when /LEFT JOIN host_inventory/
        [ @host_row ].compact
      when /FROM interface/
        @interfaces
      when /FROM hosts_groups/
        @groups
      when /FROM hosts_templates/
        @templates
      else
        []
      end
    end
  end
end
