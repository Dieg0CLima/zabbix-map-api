class Site < ApplicationRecord
  require "securerandom"

  belongs_to :organization

  has_many :devices, dependent: :restrict_with_error
  has_many :map_nodes, as: :mappable, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :external_id, presence: true
  validates :slug, uniqueness: { scope: :organization_id }
  validates :external_id, uniqueness: { scope: :organization_id }

  before_validation :ensure_external_id
  before_validation :ensure_slug

  private

  def ensure_external_id
    return if external_id.present?

    base = slug.presence || name.to_s.parameterize.presence || "site"
    self.external_id = "#{base}-#{SecureRandom.hex(4)}"
  end

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
