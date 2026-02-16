class NetworkMap < ApplicationRecord
  belongs_to :organization

  has_many :map_nodes, dependent: :destroy
  has_many :network_cables, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :source_type, inclusion: { in: %w[manual zabbix hybrid] }
end
