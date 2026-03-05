class CreateNetworkLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :network_links do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :label
      t.references :source_device, foreign_key: { to_table: :devices }
      t.references :target_device, foreign_key: { to_table: :devices }
      t.references :source_site, foreign_key: { to_table: :sites }
      t.references :target_site, foreign_key: { to_table: :sites }
      t.string :link_type, null: false, default: "logical"
      t.integer :bandwidth_mbps
      t.string :status, null: false, default: "planned"
      t.string :zabbix_item_ref
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :network_links, [:organization_id, :external_id], unique: true
    add_index :network_links, [:organization_id, :zabbix_item_ref]
  end
end
