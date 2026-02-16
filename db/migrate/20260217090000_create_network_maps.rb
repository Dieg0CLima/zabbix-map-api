class CreateNetworkMaps < ActiveRecord::Migration[8.0]
  def change
    create_table :network_maps do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :source_type, null: false, default: "manual"
      t.string :zabbix_mapid

      t.timestamps
    end

    add_index :network_maps, [ :organization_id, :name ], unique: true
    add_index :network_maps, [ :organization_id, :zabbix_mapid ], unique: true
  end
end
