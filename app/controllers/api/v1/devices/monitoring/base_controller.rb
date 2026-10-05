class Api::V1::Devices::Monitoring::BaseController < Api::V1::BaseController
  # Fail closed: every request that is not GET/HEAD needs editor/admin, whatever the
  # action is called, so a future write action cannot be born open to viewers.
  # Declared before set_device so the guard answers before the device is looked up
  # (same 403 for a missing or foreign device).
  before_action :require_editor_or_admin!, unless: -> { request.get? || request.head? }
  before_action :set_device

  private

  def set_device
    @device = find_record(current_organization.devices, params[:device_id])
  end

  def monitoring_profile
    return @monitoring_profile if defined?(@monitoring_profile)

    @monitoring_profile = @device.monitoring_profile
    return @monitoring_profile if @monitoring_profile.present?

    if @device.zabbix_host_link.present?
      @monitoring_profile = Devices::MonitoringProfileSync.new(device: @device).call
    end

    @monitoring_profile
  end
end
