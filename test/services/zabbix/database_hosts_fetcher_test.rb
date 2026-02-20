require "test_helper"

class Zabbix::DatabaseHostsFetcherTest < ActiveSupport::TestCase
  test "fetches and normalizes hosts from postgresql zabbix database" do
    connection = build_connection

    fake_rows = [
      {
        "hostid" => "10084",
        "host" => "srv-web-01",
        "name" => "Servidor Web 01",
        "status" => "0"
      }
    ]

    fake_client = Minitest::Mock.new
    fake_client.expect(:exec_params, fake_rows, [String, [100]])

    fake_database_connection = Minitest::Mock.new
    fake_database_connection.expect(:with_client, nil) { |&block| block.call(fake_client, :postgresql) }

    fetcher = Zabbix::DatabaseHostsFetcher.new(connection:, limit: 100)

    fetcher.stub(:database_connection, fake_database_connection) do
      hosts = fetcher.call

      assert_equal 1, hosts.size
      assert_equal "10084", hosts.first[:hostid]
      assert_equal "srv-web-01", hosts.first[:host]
      assert_equal "Servidor Web 01", hosts.first[:name]
    end

    fake_client.verify
    fake_database_connection.verify
  end

  test "fetches hosts from mysql adapter" do
    connection = build_connection(db_adapter: "mysql")

    fake_statement = Minitest::Mock.new
    fake_statement.expect(:execute, [{ "hostid" => "500", "host" => "srv-db-01", "name" => "Servidor DB", "status" => "0" }], [200])
    fake_statement.expect(:close, nil)

    fake_client = Minitest::Mock.new
    fake_client.expect(:prepare, fake_statement, [String])

    fake_database_connection = Minitest::Mock.new
    fake_database_connection.expect(:with_client, nil) { |&block| block.call(fake_client, :mysql) }

    fetcher = Zabbix::DatabaseHostsFetcher.new(connection:)

    fetcher.stub(:database_connection, fake_database_connection) do
      hosts = fetcher.call
      assert_equal "500", hosts.first[:hostid]
      assert_equal "Servidor DB", hosts.first[:name]
    end

    fake_statement.verify
    fake_client.verify
    fake_database_connection.verify
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
