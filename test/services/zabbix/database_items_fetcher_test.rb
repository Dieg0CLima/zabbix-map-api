require "test_helper"

class Zabbix::DatabaseItemsFetcherTest < ActiveSupport::TestCase
  test "fetches and normalizes items from postgresql zabbix database" do
    connection = build_connection

    fake_client = Minitest::Mock.new
    fake_rows = [
      {
        "itemid" => "10101",
        "name" => "CPU load",
        "key_" => "system.cpu.load",
        "value_type" => "0",
        "units" => "%",
        "status" => "0",
        "state" => "0",
        "lastvalue" => "10.2",
        "lastclock" => "1700000000",
        "hostid" => "10084",
        "host" => "srv-web-01"
      }
    ]

    fake_client.expect(:exec_params, fake_rows, [String, [50]])

    fake_database_connection = Minitest::Mock.new
    fake_database_connection.expect(:with_client, nil) { |&block| block.call(fake_client, :postgresql) }

    fetcher = Zabbix::DatabaseItemsFetcher.new(connection:, limit: 50)

    fetcher.stub(:database_connection, fake_database_connection) do
      items = fetcher.call

      assert_equal 1, items.size
      assert_equal "10101", items.first[:itemid]
      assert_equal "system.cpu.load", items.first[:key_]
      assert_equal "10084", items.first.dig(:host, :hostid)
      assert_instance_of ActiveSupport::TimeWithZone, items.first[:lastclock]
    end

    fake_client.verify
    fake_database_connection.verify
  end

  test "uses hostid filter when provided for postgresql" do
    connection = build_connection

    fake_client = Minitest::Mock.new
    fake_client.expect(:exec_params, [], [String, ["10084", 200]])

    fake_database_connection = Minitest::Mock.new
    fake_database_connection.expect(:with_client, nil) { |&block| block.call(fake_client, :postgresql) }

    fetcher = Zabbix::DatabaseItemsFetcher.new(connection:, hostid: "10084")

    fetcher.stub(:database_connection, fake_database_connection) do
      fetcher.call
    end

    fake_client.verify
    fake_database_connection.verify
  end

  test "fetches items from mysql adapter" do
    connection = build_connection(db_adapter: "mysql")

    fake_statement = Minitest::Mock.new
    fake_statement.expect(:execute, [{ "itemid" => "77", "name" => "Mem", "key_" => "vm.memory", "value_type" => "3", "units" => "B", "status" => "0", "state" => "0", "lastvalue" => "100", "lastclock" => "1700000001", "hostid" => "500", "host" => "srv-db-01" }], [200])
    fake_statement.expect(:close, nil)

    fake_client = Minitest::Mock.new
    fake_client.expect(:prepare, fake_statement, [String])

    fake_database_connection = Minitest::Mock.new
    fake_database_connection.expect(:with_client, nil) { |&block| block.call(fake_client, :mysql) }

    fetcher = Zabbix::DatabaseItemsFetcher.new(connection:)
    fetcher.stub(:database_connection, fake_database_connection) do
      items = fetcher.call
      assert_equal "77", items.first[:itemid]
      assert_equal "srv-db-01", items.first.dig(:host, :name)
    end

    fake_database_connection.verify
    fake_client.verify
    fake_statement.verify
  end

  test "raises unsupported adapter error for unsupported adapters" do
    connection = build_connection(db_adapter: "sqlite")

    fake_database_connection = Object.new
    def fake_database_connection.with_client
      raise Zabbix::DatabaseConnection::UnsupportedAdapterError, "Only postgresql and mysql adapters are currently supported"
    end

    fetcher = Zabbix::DatabaseItemsFetcher.new(connection:)

    fetcher.stub(:database_connection, fake_database_connection) do
      error = assert_raises(Zabbix::DatabaseItemsFetcher::UnsupportedAdapterError) do
        fetcher.call
      end

      assert_equal "Only postgresql and mysql adapters are currently supported", error.message
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
end
