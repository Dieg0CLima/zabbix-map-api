class NetworkMap < ApplicationRecord
  belongs_to :organization
  belongs_to :zabbix_connection, optional: true

  # New domain model: elements are polymorphic references to Site/Device
  has_many :map_elements, dependent: :destroy

  # Legacy: kept during migration, will be removed after cutover
  has_many :map_pops, dependent: :destroy
  has_many :map_nodes, dependent: :destroy

  has_many :network_cables, dependent: :destroy
  has_many :network_map_snapshots, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :source_type, inclusion: { in: %w[manual zabbix hybrid] }
  validates :active_base_layer, inclusion: { in: %w[standard terrain dark] }
end
