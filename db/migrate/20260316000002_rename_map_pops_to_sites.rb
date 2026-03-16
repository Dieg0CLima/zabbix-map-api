class RenameMapPopsToSites < ActiveRecord::Migration[8.0]
  def change
    rename_table :map_pops, :sites

    add_column :sites, :address, :string
    add_column :sites, :status, :string, default: "active", null: false
  end
end
