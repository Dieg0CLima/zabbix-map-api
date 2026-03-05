class Site < ApplicationRecord
  STATUSES = %w[active planned retired].freeze

  belongs_to :organization

  has_many :devices, dependent: :nullify
  has_many :map_pops, dependent: :nullify
  has_many :source_network_links,
           class_name: "NetworkLink",
           foreign_key: :source_site_id,
           inverse_of: :source_site,
           dependent: :nullify
  has_many :target_network_links,
           class_name: "NetworkLink",
           foreign_key: :target_site_id,
           inverse_of: :target_site,
           dependent: :nullify

  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }

  before_validation :apply_defaults

  private

  def apply_defaults
    self.external_id ||= "site-#{SecureRandom.uuid}"
  end
end
