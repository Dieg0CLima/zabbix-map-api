class Site < ApplicationRecord
  STATUSES = %w[active inactive maintenance].freeze

  belongs_to :organization

  has_many :devices, dependent: :nullify
  has_many :map_elements, as: :mappable, dependent: :destroy

  before_validation :assign_external_id

  validates :name, presence: true
  validates :external_id, presence: true, uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }
  validates :lat, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :lng, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  private

  def assign_external_id
    self.external_id ||= "site-#{SecureRandom.uuid}"
  end
end
