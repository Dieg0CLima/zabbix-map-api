class CreateZabbixItems < ActiveRecord::Migration[8.0]
  def change
    create_table :zabbix_items do |t|
      t.references :zabbix_connection, null: false, foreign_key: true
      t.references :zabbix_host, foreign_key: { to_table: :zabbix_hosts }
      t.string :itemid, null: false
      t.string :name, null: false
      t.string :key_, null: false
      t.string :value_type
      t.string :units
      t.string :status
      t.string :state
      t.text :lastvalue
      t.datetime :lastclock
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :zabbix_items, [ :zabbix_connection_id, :itemid ], unique: true
    add_index :zabbix_items, [ :zabbix_connection_id, :zabbix_host_id ]
    add_index :zabbix_items, [ :zabbix_connection_id, :key_ ]
  end
end
