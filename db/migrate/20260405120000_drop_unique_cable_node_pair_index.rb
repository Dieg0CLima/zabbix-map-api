class DropUniqueCableNodePairIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :network_cables, name: :index_network_cables_on_map_source_target, if_exists: true
    remove_index :network_cables, name: :index_network_cables_on_map_source_target_elements, if_exists: true
  end
end
