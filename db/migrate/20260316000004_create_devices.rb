class CreateDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      t.bigint :organization_id, null: false
      t.bigint :site_id
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :device_type
      t.string :zabbix_ref
      t.string :status
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :devices, [:organization_id, :external_id], unique: true
    add_index :devices, [:organization_id, :name]
    add_index :devices, :organization_id
    add_index :devices, :site_id
    add_foreign_key :devices, :organizations
    add_foreign_key :devices, :sites
  end
end
