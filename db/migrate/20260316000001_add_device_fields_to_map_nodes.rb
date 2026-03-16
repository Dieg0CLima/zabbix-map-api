class AddDeviceFieldsToMapNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :map_nodes, :hostname,    :string
    add_column :map_nodes, :ip_address,  :string
    add_column :map_nodes, :description, :text
  end
end
