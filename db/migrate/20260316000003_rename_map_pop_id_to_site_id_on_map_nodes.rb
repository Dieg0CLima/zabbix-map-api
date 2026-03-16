class RenameMapPopIdToSiteIdOnMapNodes < ActiveRecord::Migration[8.0]
  def change
    rename_column :map_nodes, :map_pop_id, :site_id
  end
end
