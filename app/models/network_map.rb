class NetworkMap < ApplicationRecord
  BASE_LAYERS = %w[standard terrain hot cycle light voyager dark satellite streets topo].freeze

  belongs_to :organization
  belongs_to :zabbix_connection, optional: true

  has_many :map_pops, dependent: :destroy
  has_many :map_nodes, dependent: :destroy
  has_many :map_edges, dependent: :destroy
  has_many :map_monitoring_bindings, through: :map_nodes
  has_many :network_cables, dependent: :destroy
  has_many :network_cable_events, dependent: :destroy
  has_many :network_map_snapshots, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :source_type, inclusion: { in: %w[manual zabbix hybrid] }
  validates :active_base_layer, inclusion: { in: BASE_LAYERS }
end
