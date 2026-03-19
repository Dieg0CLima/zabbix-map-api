class MapMonitoringBinding < ApplicationRecord
  DISPLAY_MODES = %w[badge pill sparkline status severity].freeze

  belongs_to :map_node
  belongs_to :zabbix_link, optional: true

  validates :metric_type, presence: true
  validates :display_mode, inclusion: { in: DISPLAY_MODES }

  validate :zabbix_link_must_match_node_organization

  private

  def zabbix_link_must_match_node_organization
    return if zabbix_link.blank?
    return if map_node.network_map.organization_id == zabbix_link.organization_id

    errors.add(:zabbix_link, "must belong to the same organization as the map")
  end
end
