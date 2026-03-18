class MapEdge < ApplicationRecord
  EDGE_TYPES = %w[physical logical uplink dependency].freeze

  belongs_to :network_map
  belongs_to :source_node, class_name: "MapNode"
  belongs_to :target_node, class_name: "MapNode"

  validates :edge_type, inclusion: { in: EDGE_TYPES }
  validate :nodes_belong_to_same_map
  validate :source_and_target_must_differ

  private

  def nodes_belong_to_same_map
    return if source_node.blank? || target_node.blank?
    return if source_node.network_map_id == network_map_id && target_node.network_map_id == network_map_id

    errors.add(:base, "nodes must belong to the same map")
  end

  def source_and_target_must_differ
    return unless source_node_id.present? && source_node_id == target_node_id

    errors.add(:target_node_id, "must be different from source node")
  end
end
