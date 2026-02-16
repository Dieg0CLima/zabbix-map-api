class MapNode < ApplicationRecord
  NODE_KINDS = %w[switch router server firewall gateway endpoint text zabbix_host].freeze

  belongs_to :network_map

  has_many :outgoing_cables,
           class_name: "NetworkCable",
           foreign_key: :source_node_id,
           inverse_of: :source_node,
           dependent: :destroy
  has_many :incoming_cables,
           class_name: "NetworkCable",
           foreign_key: :target_node_id,
           inverse_of: :target_node,
           dependent: :destroy

  validates :label, presence: true
  validates :node_kind, inclusion: { in: NODE_KINDS }
  validates :x, :y, presence: true
end
