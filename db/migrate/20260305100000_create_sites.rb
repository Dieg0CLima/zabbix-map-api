class CreateSites < ActiveRecord::Migration[8.0]
  def change
    create_table :sites do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :address
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :status, null: false, default: "active"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :sites, [:organization_id, :external_id], unique: true
    add_index :sites, [:organization_id, :name], unique: true
    add_index :sites, [:organization_id, :status]
  end
end
