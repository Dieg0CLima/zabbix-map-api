class AddDbPasswordToZabbixConnections < ActiveRecord::Migration[8.0]
  def change
    add_column :zabbix_connections, :db_password, :text
  end
end
