class DeviceMonitoringProfile < ApplicationRecord
  belongs_to :device, inverse_of: :monitoring_profile

  has_many :device_monitoring_items,
           class_name: "DeviceMonitoringItem",
           dependent: :destroy,
           inverse_of: :profile

  validates :device_id, uniqueness: true

  delegate :organization, to: :device

  # ---------------------------------------------------------------------------
  # Host context — all delegated to the device's ZabbixLink (single source of
  # truth). Never stored directly on this record.
  # ---------------------------------------------------------------------------

  def linked?
    zabbix_host_link.present?
  end

  def zabbix_connection
    @zabbix_connection ||= zabbix_host_link&.zabbix_connection
  end

  def zabbix_hostid
    zabbix_host_link&.external_id
  end

  def host_label
    zabbix_host_link&.name.presence || zabbix_hostid
  end

  def host_metadata_with_defaults
    zabbix_host_link&.metadata || {}
  end

  private

  def zabbix_host_link
    @zabbix_host_link ||= device.zabbix_host_link
  end
end
