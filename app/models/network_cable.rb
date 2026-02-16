class NetworkCable < ApplicationRecord
  CABLE_TYPES = %w[copper fiber wireless logical].freeze
  STATUSES = %w[up down degraded unknown].freeze

  belongs_to :network_map
  belongs_to :source_node, class_name: "MapNode", inverse_of: :outgoing_cables
  belongs_to :target_node, class_name: "MapNode", inverse_of: :incoming_cables

  has_many :network_cable_points, dependent: :destroy

  validates :cable_type, inclusion: { in: CABLE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :source_node_id, uniqueness: {
    scope: [ :target_node_id, :network_map_id ],
    message: "already has a cable in this map"
  }
  validates :source_node_id, comparison: { other_than: :target_node_id }
  validates :bandwidth_mbps,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true, only_integer: true }
  validates :length_meters,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  validate :nodes_must_belong_to_the_same_map

  private

  def nodes_must_belong_to_the_same_map
    return if source_node.blank? || target_node.blank? || network_map.blank?

    if source_node.network_map_id != network_map_id || target_node.network_map_id != network_map_id
      errors.add(:base, "source and target nodes must belong to the same network map")
    end
  end
end
