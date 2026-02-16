class NetworkCablePoint < ApplicationRecord
  belongs_to :network_cable

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :x, :y, presence: true
  validates :position, uniqueness: { scope: :network_cable_id }
end
