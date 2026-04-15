class Api::V1::Devices::Monitoring::HostLinksController < Api::V1::Devices::Monitoring::BaseController
  def update
    service = Devices::ZabbixHostLinkUpserter.new(
      device: @device,
      organization: current_organization,
      params: host_link_params
    )
    service.call
    @device.reload
    profile = Devices::MonitoringProfileSync.new(device: @device).call
    render_data(data: Api::V1::Devices::Monitoring::ProfileSerializer.new(profile).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def show
    profile = monitoring_profile
    render_data(data: Api::V1::Devices::Monitoring::ProfileSerializer.new(profile).as_json)
  end

  private

  def host_link_params
    params.require(:monitoring_host_link).permit(:zabbix_connection_id, :zabbix_host_id)
  end
end
