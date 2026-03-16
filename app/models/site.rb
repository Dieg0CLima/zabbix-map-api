class Site < ApplicationRecord
  belongs_to :organization
  has_many :devices, dependent: :nullify
  has_many :map_pops, dependent: :nullify

  validates :name, :external_id, presence: true
  validates :external_id, uniqueness: { scope: :organization_id }

  before_validation :apply_defaults

  private

  def apply_defaults
    self.external_id ||= "site-#{SecureRandom.uuid}"
  end
end
