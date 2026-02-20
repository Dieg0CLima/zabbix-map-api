require "test_helper"

class Api::V1::ZabbixConnectionsControllerTest < ActiveSupport::TestCase
  test "zabbix_connection_params removes blank db_password" do
    controller = Api::V1::ZabbixConnectionsController.new
    raw_params = ActionController::Parameters.new(
      zabbix_connection: {
        name: "Conexao 1",
        connection_mode: "database",
        db_adapter: "postgresql",
        db_host: "localhost",
        db_port: 5432,
        db_name: "zabbix",
        db_username: "zabbix",
        db_password: ""
      }
    )

    controller.stub(:params, raw_params) do
      permitted = controller.send(:zabbix_connection_params)
      assert_nil permitted[:db_password]
    end
  end

  test "zabbix_connection_params keeps filled db_password" do
    controller = Api::V1::ZabbixConnectionsController.new
    raw_params = ActionController::Parameters.new(
      zabbix_connection: {
        name: "Conexao 1",
        connection_mode: "database",
        db_adapter: "postgresql",
        db_host: "localhost",
        db_port: 5432,
        db_name: "zabbix",
        db_username: "zabbix",
        db_password: "new-secret"
      }
    )

    controller.stub(:params, raw_params) do
      permitted = controller.send(:zabbix_connection_params)
      assert_equal "new-secret", permitted[:db_password]
    end
  end

  test "assign_db_password sets password when provided" do
    controller = Api::V1::ZabbixConnectionsController.new
    connection = ZabbixConnection.new
    raw_params = ActionController::Parameters.new(
      zabbix_connection: {
        db_password: "new-secret"
      }
    )

    controller.stub(:params, raw_params) do
      controller.send(:assign_db_password, connection)
    end

    assert_equal "new-secret", connection.db_password
  end

  test "assign_db_password keeps existing password when blank value is provided" do
    controller = Api::V1::ZabbixConnectionsController.new
    connection = ZabbixConnection.new
    connection.db_password = "already-saved"
    raw_params = ActionController::Parameters.new(
      zabbix_connection: {
        db_password: ""
      }
    )

    controller.stub(:params, raw_params) do
      controller.send(:assign_db_password, connection)
    end

    assert_equal "already-saved", connection.db_password
  end
end
