class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices, if_not_exists: true do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :site, foreign_key: true
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :device_type
      t.string :zabbix_ref
      t.bigint :zabbix_host_id
      t.string :status, default: "active", null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :devices, %i[organization_id external_id], unique: true, if_not_exists: true
    add_index :devices, %i[organization_id name], if_not_exists: true

    unless column_exists?(:devices, :zabbix_host_id)
      add_column :devices, :zabbix_host_id, :bigint
    end
    add_index :devices, :zabbix_host_id, if_not_exists: true

    unless foreign_key_exists?(:devices, to_table: :zabbix_hosts)
      add_foreign_key :devices, :zabbix_hosts, on_delete: :nullify
    end
  end
end
