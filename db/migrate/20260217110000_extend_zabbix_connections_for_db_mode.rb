class ExtendZabbixConnectionsForDbMode < ActiveRecord::Migration[8.0]
  def change
    add_column :zabbix_connections, :connection_mode, :string, null: false, default: "api"

    change_column_null :zabbix_connections, :base_url, true

    add_column :zabbix_connections, :db_adapter, :string
    add_column :zabbix_connections, :db_host, :string
    add_column :zabbix_connections, :db_port, :integer
    add_column :zabbix_connections, :db_name, :string
    add_column :zabbix_connections, :db_username, :string
    add_column :zabbix_connections, :db_password_ciphertext, :string

    add_index :zabbix_connections, [ :organization_id, :connection_mode ]
  end
end
