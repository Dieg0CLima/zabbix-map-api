class Membership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  ROLES = %w[admin editor viewer].freeze

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }
end
