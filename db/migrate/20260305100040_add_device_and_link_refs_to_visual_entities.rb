class AddDeviceAndLinkRefsToVisualEntities < ActiveRecord::Migration[8.0]
  def change
    add_reference :map_nodes, :device, null: true, foreign_key: true
    add_reference :network_cables, :network_link, null: true, foreign_key: true
  end
end
