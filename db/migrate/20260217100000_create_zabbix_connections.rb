class CreateZabbixConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :zabbix_connections do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :base_url, null: false
      t.string :api_token_ciphertext
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
  end
end
