class Devices::MonitoringProfileSync
  def initialize(device:)
    @device = device
  end

  def call
    host_link = latest_host_link
    return destroy_profile unless host_link.present?

    profile = @device.monitoring_profile || @device.build_monitoring_profile
    profile.synced_at = Time.current
    profile.save! if profile.new_record? || profile.changed?
    profile
  end

  private

  def destroy_profile
    @device.monitoring_profile&.destroy
    @device.association(:monitoring_profile).reset
    nil
  end

  def latest_host_link
    @device.zabbix_links.where(resource_type: "host").order(id: :desc).first
  end
end
