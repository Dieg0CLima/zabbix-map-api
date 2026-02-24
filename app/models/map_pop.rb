class MapPop < ApplicationRecord
  belongs_to :network_map

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

  private

  def apply_defaults
    self.external_id ||= "pop-#{SecureRandom.uuid}"
  end
end
