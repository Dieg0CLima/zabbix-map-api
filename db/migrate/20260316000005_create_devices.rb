class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :site, null: true, foreign_key: true
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :device_type
      t.string :zabbix_ref
      t.string :status, null: false, default: "active"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :devices, [:organization_id, :external_id], unique: true
  end
end
