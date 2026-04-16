class NetworkCableItem < ApplicationRecord
  METRIC_ROLES = %w[
    bandwidth_in
    bandwidth_out
    status
    error_in
    error_out
    crc_in
    crc_out
  ].freeze

  belongs_to :network_cable
  belongs_to :zabbix_item, class_name: "Zabbix::Item"

  validates :zabbix_item_id, uniqueness: { scope: :network_cable_id, message: "já está vinculado a este cabo" }
  validates :metric_role, inclusion: { in: METRIC_ROLES }
  validates :display_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
