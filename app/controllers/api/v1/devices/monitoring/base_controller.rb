class Api::V1::Devices::Monitoring::BaseController < Api::V1::BaseController
  WRITE_ACTIONS = %w[create update destroy].freeze

  # Write actions need editor/admin. Declared before set_device so the guard answers
  # before the device is looked up (same 403 for a missing or foreign device). A
  # condition instead of `only:` because not every subclass defines all of them.
  before_action :require_editor_or_admin!, if: -> { WRITE_ACTIONS.include?(action_name) }
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
