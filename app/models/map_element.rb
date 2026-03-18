class MapElement < ApplicationRecord
  MAPPABLE_TYPES = %w[Site Device].freeze

  belongs_to :network_map
  belongs_to :mappable, polymorphic: true

  has_many :map_element_items, dependent: :destroy

  has_many :source_cables,
           class_name: "NetworkCable",
           foreign_key: :source_element_id,
           inverse_of: :source_element,
           dependent: :nullify

  has_many :target_cables,
           class_name: "NetworkCable",
           foreign_key: :target_element_id,
           inverse_of: :target_element,
           dependent: :nullify

  before_validation :assign_external_id

  validates :external_id, presence: true, uniqueness: { scope: :network_map_id }
  validates :mappable_type, inclusion: { in: MAPPABLE_TYPES }
  validates :lat, :lng, presence: true
  validates :lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :lng, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :size_override,
            numericality: { only_integer: true, greater_than_or_equal_to: 18, less_than_or_equal_to: 56 },
            allow_nil: true
  validates :display_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :mappable_belongs_to_same_organization
  validate :entity_unique_per_map

  def site?
    mappable_type == "Site"
  end

  def device?
    mappable_type == "Device"
  end

  # Resolved display label: override → entity name
  def display_label
    label_override.presence || mappable&.name
  end

  private

  def assign_external_id
    self.external_id ||= "elem-#{SecureRandom.uuid}"
  end

  def mappable_belongs_to_same_organization
    return if mappable.blank? || network_map.blank?

    unless mappable.respond_to?(:organization_id) &&
           mappable.organization_id == network_map.organization_id
      errors.add(:mappable, "must belong to the same organization as the map")
    end
  end

  def entity_unique_per_map
    return if new_record? || !network_map_id_changed? && !mappable_id_changed? && !mappable_type_changed?

    if MapElement.where(
         network_map_id: network_map_id,
         mappable_type:  mappable_type,
         mappable_id:    mappable_id
       ).where.not(id: id).exists?
      errors.add(:mappable, "already present in this map")
    end
  end
end
