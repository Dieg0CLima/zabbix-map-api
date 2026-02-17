class CreateZabbixHosts < ActiveRecord::Migration[8.0]
  def change
    create_table :zabbix_hosts do |t|
      t.references :zabbix_connection, null: false, foreign_key: true
      t.string :hostid, null: false
      t.string :name, null: false
      t.string :status
      t.string :available
      t.jsonb :interfaces, null: false, default: []
      t.jsonb :tags, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :zabbix_hosts, [ :zabbix_connection_id, :hostid ], unique: true
    add_index :zabbix_hosts, [ :zabbix_connection_id, :name ]
  end
end
