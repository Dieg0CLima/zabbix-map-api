class Devices::MonitoringProfileSync
  def initialize(device:)
    @device = device
  end

  def call
    return destroy_profile unless @device.zabbix_host_link.present?

    profile = @device.monitoring_profile || @device.build_monitoring_profile
    profile.synced_at = Time.current
    profile.save! if profile.new_record? || profile.changed?
    profile
  end

  private

  def destroy_profile
    @device.monitoring_profile&.destroy
    nil
  end
end
