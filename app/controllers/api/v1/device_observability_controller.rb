class Api::V1::DeviceObservabilityController < Api::V1::BaseController
  before_action :set_device

  def show
    render_data(data: Api::V1::DeviceObservabilitySummarySerializer.new(summary_service.call).as_json)
  end

  def events
    render_data(data: Api::V1::DeviceObservabilityEventsSerializer.new(events_service.call).as_json)
  end

  def interfaces
    render_data(data: Api::V1::DeviceObservabilityInterfacesSerializer.new(interfaces_service.call.fetch(:data)).as_json)
  end

  def metrics
    render_data(data: Api::V1::DeviceObservabilityMetricsSerializer.new(metrics_service.call).as_json)
  end

  private

  def set_device
    @device = find_record(current_organization.devices.includes(:zabbix_host_link, :zabbix_connection), params[:device_id] || params[:id])
  end

  def summary_service
    Zabbix::Observability::FetchDeviceSummary.new(device: @device)
  end

  def events_service
    Zabbix::Observability::FetchEvents.new(device: @device)
  end

  def interfaces_service
    Zabbix::Observability::FetchInterfaces.new(device: @device)
  end

  def metrics_service
    Zabbix::Observability::FetchMetrics.new(device: @device)
  end
end
