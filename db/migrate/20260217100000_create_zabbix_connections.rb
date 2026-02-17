class CreateZabbixConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :zabbix_connections do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false

      # Modo de conexão com Zabbix
      # api: usa API JSON-RPC
      # db: usa acesso direto ao banco Zabbix
      # hybrid: permite as duas estratégias
      t.string :connection_mode, null: false, default: "api"

      # API JSON-RPC
      t.string :base_url
      t.string :api_token_ciphertext

      # Conexão direta com banco
      t.string :db_adapter
      t.string :db_host
      t.integer :db_port
      t.string :db_name
      t.string :db_username
      t.string :db_password_ciphertext

      t.string :status, null: false, default: "active"
      t.boolean :default_connection, null: false, default: false
      t.datetime :last_synced_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :zabbix_connections, [ :organization_id, :name ], unique: true
    add_index :zabbix_connections, [ :organization_id, :default_connection ],
              unique: true,
              where: "default_connection = true",
              name: "index_zabbix_connections_on_org_default_true"

    add_index :zabbix_connections, [ :organization_id, :connection_mode ]
  end
end
