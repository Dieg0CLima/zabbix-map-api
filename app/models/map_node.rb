class MapNode < ApplicationRecord
  NODE_KINDS = %w[switch router server firewall gateway endpoint text zabbix_host olt cto splitter generic].freeze

  belongs_to :network_map
  belongs_to :map_pop, optional: true
  belongs_to :mappable, polymorphic: true, optional: true
  belongs_to :zabbix_host, class_name: "Zabbix::Host", optional: true

  has_many :map_node_items, dependent: :destroy
  has_many :monitoring_bindings, class_name: "MapMonitoringBinding", dependent: :destroy
  has_many :outgoing_edges,
           class_name: "MapEdge",
           foreign_key: :source_node_id,
           inverse_of: :source_node,
           dependent: :destroy
  has_many :incoming_edges,
           class_name: "MapEdge",
           foreign_key: :target_node_id,
           inverse_of: :target_node,
           dependent: :destroy

  before_validation :resolve_map_pop_external_id
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

  validate :mappable_presence_for_inventory_projection
  validate :mappable_uniqueness_within_map
  validate :pop_must_belong_to_same_map
  validate :map_pop_external_id_must_exist
  validate :zabbix_host_id_format
  validate :zabbix_host_must_belong_to_network_map_connection

  def map_pop_id=(value)
    @map_pop_external_id = nil

    if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
      @map_pop_external_id = value
      return super(nil)
    end

    super(value)
  end

  private

  def apply_default_visuals
    self.external_id ||= "node-#{SecureRandom.uuid}"
    self.icon ||= "pi-server"
    self.color ||= "#2563eb"
    self.size ||= 30
    self.visible = true if visible.nil?
    self.collapsed = false if collapsed.nil?
    self.width ||= size
    self.height ||= size
    self.label ||= label_override || mappable_label
    self.lat ||= x
    self.lng ||= y
    self.x ||= lat
    self.y ||= lng
  end

  def resolve_map_pop_external_id
    return if @map_pop_external_id.blank? || network_map.blank?

    self.map_pop = network_map.map_pops.find_by(external_id: @map_pop_external_id)
  end

  def map_pop_external_id_must_exist
    return if @map_pop_external_id.blank? || map_pop.present?

    errors.add(:map_pop_id, "must reference an existing pop external_id")
  end

  def mappable_presence_for_inventory_projection
    return if mappable.present?
    return if map_pop.present? || label.present?

    errors.add(:mappable, "must reference a documented resource")
  end

  def mappable_uniqueness_within_map
    return if mappable.blank? || network_map_id.blank?
    return unless self.class.where(network_map_id:, mappable_type:, mappable_id:).where.not(id: id).exists?

    errors.add(:mappable_id, "is already present in this map")
  end

  def pop_must_belong_to_same_map
    return if map_pop.blank? || network_map.blank?
    return if map_pop.network_map_id == network_map_id

    errors.add(:map_pop, "must belong to the same network map")
  end

  def zabbix_host_id_format
    return if zabbix_host_id_before_type_cast.blank?
    return if zabbix_host_id_before_type_cast.to_s.match?(/\A\d+\z/)

    errors.add(:zabbix_host_id, "must be numeric")
  end

  def zabbix_host_must_belong_to_network_map_connection
    return if zabbix_host.blank? || network_map.blank?
    return if network_map.zabbix_connection_id.blank?
    return if zabbix_host.zabbix_connection_id == network_map.zabbix_connection_id

    errors.add(:zabbix_host_id, "must belong to the network map Zabbix connection")
  end

  def mappable_label
    return unless mappable.respond_to?(:name)

    mappable.name
  end
end
