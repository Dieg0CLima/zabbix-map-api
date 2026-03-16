class CreateSites < ActiveRecord::Migration[7.1]
  def change
    create_table :sites do |t|
      t.bigint :organization_id, null: false
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :address
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :status
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :sites, [:organization_id, :external_id], unique: true
    add_index :sites, [:organization_id, :name]
    add_index :sites, :organization_id
    add_foreign_key :sites, :organizations
  end
end
