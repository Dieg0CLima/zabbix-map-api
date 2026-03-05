class MapPop < ApplicationRecord
  belongs_to :network_map
  belongs_to :site, optional: true

  before_validation :resolve_site_external_id
  before_validation :apply_defaults

  has_many :map_nodes, dependent: :nullify

  has_many :source_cables,
           class_name: "NetworkCable",
           foreign_key: :source_pop_id,
           inverse_of: :source_pop,
           dependent: :nullify
  has_many :target_cables,
           class_name: "NetworkCable",
           foreign_key: :target_pop_id,
           inverse_of: :target_pop,
           dependent: :nullify

  validates :name, :external_id, :lat, :lng, :color, presence: true
  validates :external_id, uniqueness: { scope: :network_map_id }

  before_destroy :ensure_no_dependencies

  def site_id=(value)
    @site_external_id = nil

    if value.is_a?(String) && value.present? && !value.match?(/\A\d+\z/)
      @site_external_id = value
      return super(nil)
    end

    super(value)
  end

  private

  def ensure_no_dependencies
    return if map_nodes.none? && source_cables.none? && target_cables.none?

    errors.add(:base, "POP possui dependências (equipamentos/cabos)")
    throw(:abort)
  end

  def resolve_site_external_id
    return if @site_external_id.blank? || network_map.blank?

    self.site = network_map.organization.sites.find_by(external_id: @site_external_id)
    return if site.present?

    errors.add(:site_id, "must reference an existing site external_id")
  end

  def apply_defaults
    self.external_id ||= "pop-#{SecureRandom.uuid}"
  end
end
