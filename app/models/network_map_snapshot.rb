class NetworkMapSnapshot < ApplicationRecord
  belongs_to :network_map

  validates :label, presence: true
  validates :state, presence: true
end
