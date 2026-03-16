class AddDeviceIdToMapNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :map_nodes, :device_id, :bigint
    add_index :map_nodes, :device_id
    add_foreign_key :map_nodes, :devices
  end
end
