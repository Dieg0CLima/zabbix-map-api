class AddSiteIdToMapPops < ActiveRecord::Migration[7.1]
  def change
    add_column :map_pops, :site_id, :bigint
    add_index :map_pops, :site_id
    add_foreign_key :map_pops, :sites
  end
end
