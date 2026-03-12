class MapNodeItem < ApplicationRecord
  belongs_to :map_node
  belongs_to :zabbix_item, class_name: "Zabbix::Item"

  validates :zabbix_item_id, uniqueness: { scope: :map_node_id, message: "já está vinculado a este nó" }
  validates :display_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
