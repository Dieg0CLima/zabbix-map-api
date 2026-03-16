class RenamePopIdsOnNetworkCables < ActiveRecord::Migration[8.0]
  def change
    rename_column :network_cables, :source_pop_id, :source_site_id
    rename_column :network_cables, :target_pop_id, :target_site_id
  end
end
