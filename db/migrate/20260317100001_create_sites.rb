class CreateSites < ActiveRecord::Migration[8.0]
  def change
    create_table :sites, if_not_exists: true do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :address
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :status, default: "active", null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :sites, %i[organization_id external_id], unique: true, if_not_exists: true
    add_index :sites, %i[organization_id name], if_not_exists: true
    add_index :sites, :organization_id, if_not_exists: true
  end
end
