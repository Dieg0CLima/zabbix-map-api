class Site < ApplicationRecord
  belongs_to :network_map

  before_validation :apply_defaults

  has_many :map_nodes, dependent: :nullify
  has_many :devices, dependent: :nullify

  has_many :source_cables,
           class_name: "NetworkCable",
           foreign_key: :source_site_id,
           inverse_of: :source_site,
           dependent: :nullify
  has_many :target_cables,
           class_name: "NetworkCable",
           foreign_key: :target_site_id,
           inverse_of: :target_site,
           dependent: :nullify

  validates :name, :external_id, :lat, :lng, :color, presence: true
  validates :external_id, uniqueness: { scope: :network_map_id }

  before_destroy :ensure_no_dependencies

  private

  def ensure_no_dependencies
    return if map_nodes.none? && source_cables.none? && target_cables.none?

    errors.add(:base, "Site possui dependências (equipamentos/cabos)")
    throw(:abort)
  end

  def apply_defaults
    self.external_id ||= "site-#{SecureRandom.uuid}"
  end
end
