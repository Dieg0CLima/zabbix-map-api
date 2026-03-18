class Api::V1::DevicesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy site_link]
  before_action :set_device, only: %i[show update destroy site_link]

  def index
    devices = current_organization.devices.order(:id)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    devices = devices.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: devices.map { |device| Api::V1::DeviceSerializer.new(device).as_json })
  end

  def dropdown
    devices = current_organization.devices.includes(:site).order(:name)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    devices = devices.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: devices.limit(50).map { |device| { value: device.id, label: device.name, code: device.hostname || device.id.to_s, meta: { site_id: device.site_id, role: device.role, status: device.status } } })
  end

  def show
    render_data(data: Api::V1::DeviceSerializer.new(@device).as_json)
  end

  def create
    device, marker = Devices::CreateDevice.new(organization: current_organization, params: device_params.to_h.symbolize_keys, map_context: map_context_params.to_h.symbolize_keys, actor: current_user).call
    render_data(data: { device: Api::V1::DeviceSerializer.new(device).as_json, marker: marker && Api::V1::MapElementSerializer.new(marker).as_json }, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    device = Devices::UpdateDevice.new(device: @device, params: device_params.to_h.symbolize_keys, actor: current_user).call
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

  def site_link
    site = params[:site_id].present? ? find_record(current_organization.sites, params[:site_id]) : nil
    return if performed?

    device = Devices::RelinkDeviceToSite.new(device: @device, site:).call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  private

  def set_device
    @device = find_record(current_organization.devices, params[:id])
  end

  def device_params
    params.require(:device).permit(:site_id, :name, :hostname, :role, :vendor, :model, :serial_number, :management_ip, :status, metadata: {})
  end

  def map_context_params
    params.fetch(:map_context, ActionController::Parameters.new).permit(:add_to_map, :network_map_id, :label_override, :color_override, :icon_override, metadata: {}, position: %i[lat lng x y])
  end
end
