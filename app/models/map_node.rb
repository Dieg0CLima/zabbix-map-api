class MapNode < ApplicationRecord
  NODE_KINDS = %w[switch router server firewall gateway endpoint text zabbix_host].freeze

  belongs_to :network_map
  belongs_to :map_pop, optional: true

  before_validation :apply_default_visuals

  has_many :outgoing_cables,
           class_name: "NetworkCable",
           foreign_key: :source_node_id,
           inverse_of: :source_node,
           dependent: :nullify
  has_many :incoming_cables,
           class_name: "NetworkCable",
           foreign_key: :target_node_id,
           inverse_of: :target_node,
           dependent: :nullify

  validates :external_id, presence: true, uniqueness: { scope: :network_map_id }
  validates :label, presence: true
  validates :node_kind, inclusion: { in: NODE_KINDS }
  validates :x, :y, :lat, :lng, presence: true
  validates :size, numericality: { only_integer: true, greater_than_or_equal_to: 18, less_than_or_equal_to: 56 }
  validates :icon, :color, presence: true

  validate :pop_must_belong_to_same_map

  private

  def apply_default_visuals
    self.external_id ||= "node-#{SecureRandom.uuid}"
    self.icon ||= "pi-server"
    self.color ||= "#2563eb"
    self.size ||= 30
    self.lat ||= x
    self.lng ||= y
    self.x ||= lat
    self.y ||= lng
  end

  def pop_must_belong_to_same_map
    return if map_pop.blank? || network_map.blank?
    return if map_pop.network_map_id == network_map_id

    errors.add(:map_pop, "must belong to the same network map")
  end
end
