require "test_helper"

# REQ-009 CA7/CA9: busca de hosts por IP no banco do Zabbix, somente leitura.
# Contrato: Zabbix::HostCandidatesFetcher.new(connection:, ip:, limit: 20).call -> Array de details_payload;
# erros de conexão são convertidos em Zabbix::HostCandidatesFetcher::Error.
class Zabbix::HostCandidatesFetcherTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Org Candidatos #{SecureRandom.hex(3)}")
    @connection = @org.zabbix_connections.create!(
      name: "Zabbix", status: "active", connection_mode: "database", db_adapter: "postgresql",
      db_host: "127.0.0.1", db_port: 5432, db_name: "zabbix", db_username: "zabbix", db_password: "secret"
    )
  end

  # Cliente falso: registra todo SQL recebido e devolve linhas vazias. Nenhuma rede.
  class RecordingClient
    attr_reader :statements, :params

    def initialize
      @statements = []
      @params = []
    end

    def exec_params(sql, params = [])
      @statements << sql
      @params << params
      []
    end

    def prepare(sql)
      @statements << sql
      statement = Object.new
      captured = @params
      statement.define_singleton_method(:execute) { |*args| captured << args; [] }
      statement.define_singleton_method(:close) { nil }
      statement
    end
  end

  def fake_database_connection(client, adapter = :postgresql)
    Class.new do
      define_method(:with_client) { |&block| block.call(client, adapter) }
    end.new
  end

  test "CA7: only SELECT statements are issued and the exact ip is sent as a bound parameter" do
    client = RecordingClient.new

    Zabbix::DatabaseConnection.stub(:new, ->(**) { fake_database_connection(client) }) do
      result = Zabbix::HostCandidatesFetcher.new(connection: @connection, ip: "10.0.0.1", limit: 20).call
      assert_equal [], result
    end

    assert client.statements.any?, "deve consultar o Zabbix"
    client.statements.each { |sql| assert_match(/\A\s*SELECT\b/i, sql) }
    assert client.params.flatten.include?("10.0.0.1"), "o IP exato deve ir como parâmetro (sem concatenar no SQL)"
    client.statements.each { |sql| assert_no_match(/10\.0\.0\.1/, sql) }
    client.statements.each { |sql| assert_no_match(/\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE)\b/i, sql) }
  end

  test "CA7: the same read-only guarantees hold for the mysql adapter" do
    client = RecordingClient.new
    mysql = @org.zabbix_connections.create!(
      name: "Zabbix MySQL", status: "active", connection_mode: "database", db_adapter: "mysql",
      db_host: "127.0.0.1", db_port: 3306, db_name: "zabbix", db_username: "zabbix", db_password: "secret"
    )

    Zabbix::DatabaseConnection.stub(:new, ->(**) { fake_database_connection(client, :mysql) }) do
      Zabbix::HostCandidatesFetcher.new(connection: mysql, ip: "10.0.0.1", limit: 20).call
    end

    client.statements.each { |sql| assert_match(/\A\s*SELECT\b/i, sql) }
    assert client.params.flatten.include?("10.0.0.1")
  end

  test "CA7: limit is capped at 20" do
    client = RecordingClient.new

    Zabbix::DatabaseConnection.stub(:new, ->(**) { fake_database_connection(client) }) do
      Zabbix::HostCandidatesFetcher.new(connection: @connection, ip: "10.0.0.1", limit: 500).call
    end

    numeric = client.params.flatten.grep(Integer)
    assert numeric.any? { |value| value <= 20 }, "limite enviado ao SQL deve ser <= 20"
    assert numeric.none? { |value| value > 20 }
  end

  test "CA9: a Zabbix connection error becomes HostCandidatesFetcher::Error" do
    broken = Class.new do
      def with_client
        raise Zabbix::DatabaseConnection::Error, "connection refused"
      end
    end.new

    Zabbix::DatabaseConnection.stub(:new, ->(**) { broken }) do
      assert_raises(Zabbix::HostCandidatesFetcher::Error) do
        Zabbix::HostCandidatesFetcher.new(connection: @connection, ip: "10.0.0.1", limit: 20).call
      end
    end
  end
end
