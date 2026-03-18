class Api::V1::DevicesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_device, only: %i[show update destroy]

  def index
    devices = current_organization.devices.order(:id)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    render_data(data: devices.map { |device| Api::V1::DeviceSerializer.new(device).as_json })
  end

  def show
    render_data(data: Api::V1::DeviceSerializer.new(@device).as_json)
  end

  def create
    device = Inventory::Devices::CreateService.new(organization: current_organization, params: device_params).call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    device = Inventory::Devices::UpdateService.new(device: @device, params: device_params).call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @device.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_record_errors(@device)
  end

  private

  def set_device
    @device = find_record(current_organization.devices, params[:id])
  end

  def device_params
    params.require(:device).permit(:site_id, :name, :hostname, :role, :vendor, :model, :serial_number, :management_ip, :status, metadata: {})
  end
end
