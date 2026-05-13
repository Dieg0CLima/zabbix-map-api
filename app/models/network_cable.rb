class NetworkCable < ApplicationRecord
  CABLE_TYPES = %w[manual feeder distribution drop copper fiber wireless logical].freeze
  STATUSES = %w[active planned maintenance disabled up down degraded unknown].freeze
  PATTERNS = %w[solid dashed dotted].freeze

  belongs_to :network_map

  belongs_to :source_pop, class_name: "MapPop", optional: true
  belongs_to :target_pop, class_name: "MapPop", optional: true

  belongs_to :source_node, class_name: "MapNode", inverse_of: :outgoing_cables, optional: true
  belongs_to :target_node, class_name: "MapNode", inverse_of: :incoming_cables, optional: true

  has_many :network_cable_points, dependent: :destroy
  has_many :network_cable_events, dependent: :destroy
  has_many :network_cable_items, dependent: :destroy
  has_one :cable_fusion_diagram, class_name: "CableFusion::Diagram", dependent: :destroy, inverse_of: :network_cable

  attr_reader :source_site_id, :target_site_id

  before_validation :resolve_pop_external_ids
  before_validation :resolve_site_endpoints
  before_validation :apply_default_visuals
  before_validation :derive_pops_from_nodes

  validates :external_id, presence: true, uniqueness: { scope: :network_map_id }
  validates :pattern, inclusion: { in: PATTERNS }
  validates :weight, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :color, presence: true

  validates :cable_type, inclusion: { in: CABLE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :source_node_id,
            comparison: { other_than: :target_node_id },
            if: -> { source_node_id.present? && target_node_id.present? }
  validates :bandwidth_mbps,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true, only_integer: true }
  validates :length_meters,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  validate :source_binding_required
  validate :endpoints_must_belong_to_the_same_map
  validate :nodes_must_match_bound_pops
  validate :source_pop_external_id_must_exist
  validate :target_pop_external_id_must_exist
  validate :source_site_must_exist_in_map
  validate :target_site_must_exist_in_map
  validate :fiber_count_must_be_positive_integer

  def source_pop_id=(value)
    @source_pop_external_id = nil

    if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
      @source_pop_external_id = value
      return super(nil)
    end

    super(value)
  end

  def target_pop_id=(value)
    @target_pop_external_id = nil

    if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
      @target_pop_external_id = value
      return super(nil)
    end

    super(value)
  end

  def source_site_id=(value)
    @source_site_id = normalize_site_id(value)
  end

  def target_site_id=(value)
    @target_site_id = normalize_site_id(value)
  end

  def source_site_id
    return @source_site_id if defined?(@source_site_id) && @source_site_id.present?

    site_id_for_node(source_node)
  end

  def target_site_id
    return @target_site_id if defined?(@target_site_id) && @target_site_id.present?

    site_id_for_node(target_node)
  end

  private

  def apply_default_visuals
    self.external_id ||= "cable-#{SecureRandom.uuid}"
    self.color ||= "#0891b2"
    self.weight ||= 4
    self.pattern ||= "solid"
    self.cable_type ||= "manual"
    self.status ||= "planned"
  end

  def resolve_pop_external_ids
    return if network_map.blank?

    if @source_pop_external_id.present?
      self.source_pop = network_map.map_pops.find_by(external_id: @source_pop_external_id)
    end

    if @target_pop_external_id.present?
      self.target_pop = network_map.map_pops.find_by(external_id: @target_pop_external_id)
    end
  end

  def resolve_site_endpoints
    return if network_map.blank?

    if @source_site_id.present?
      self.source_node = network_map.map_nodes.find_by(mappable_type: "Site", mappable_id: @source_site_id)
    end

    if @target_site_id.present?
      self.target_node = network_map.map_nodes.find_by(mappable_type: "Site", mappable_id: @target_site_id)
    end
  end

  def derive_pops_from_nodes
    self.source_pop ||= source_node&.map_pop
    self.target_pop ||= target_node&.map_pop
  end

  def source_site_must_exist_in_map
    return if @source_site_id.blank? || source_node.present?

    errors.add(:source_site_id, "must reference a Site marker attached to this map")
  end

  def target_site_must_exist_in_map
    return if @target_site_id.blank? || target_node.present?

    errors.add(:target_site_id, "must reference a Site marker attached to this map")
  end

  def source_binding_required
    return if source_pop_id.present? || source_node_id.present? || source_element_id.present?

    errors.add(:source_pop_id, "é obrigatório")
  end

  def endpoints_must_belong_to_the_same_map
    return if network_map.blank?

    [ source_pop, target_pop, source_node, target_node ].compact.each do |record|
      next if record.network_map_id == network_map_id

      errors.add(:base, "all endpoints must belong to the same network map")
      break
    end
  end

  def nodes_must_match_bound_pops
    if source_node.present? && source_pop.present? && source_node.map_pop_id != source_pop_id
      errors.add(:source_node, "must belong to source_pop")
    end

    if target_node.present? && target_pop.present? && target_node.map_pop_id != target_pop_id
      errors.add(:target_node, "must belong to target_pop")
    end
  end

  def source_pop_external_id_must_exist
    return if @source_pop_external_id.blank? || source_pop.present?

    errors.add(:source_pop_id, "must reference an existing pop external_id")
  end

  def target_pop_external_id_must_exist
    return if @target_pop_external_id.blank? || target_pop.present?

    errors.add(:target_pop_id, "must reference an existing pop external_id")
  end

  def fiber_count_must_be_positive_integer
    return unless metadata.is_a?(Hash) && metadata.key?("fiber_count")

    fiber_count = metadata["fiber_count"]
    return if fiber_count.is_a?(Integer) && fiber_count.positive?

    errors.add(:metadata, "fiber_count deve ser inteiro positivo")
  end

  def normalize_site_id(value)
    return nil if value.blank?

    value.to_i
  end

  def site_id_for_node(node)
    return nil unless node&.mappable_type == "Site"

    node.mappable_id
  end
end
