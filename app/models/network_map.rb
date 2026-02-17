class NetworkMap < ApplicationRecord
  belongs_to :organization
  belongs_to :zabbix_connection, optional: true

  has_many :map_nodes, dependent: :destroy
  has_many :network_cables, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :source_type, inclusion: { in: %w[manual zabbix hybrid] }
end
