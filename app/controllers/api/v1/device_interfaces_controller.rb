class Api::V1::DeviceInterfacesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_device
  before_action :set_device_interface, only: %i[update destroy]

  def index
    render_data(data: @device.device_interfaces.order(:id).map { |iface| Api::V1::DeviceInterfaceSerializer.new(iface).as_json })
  end

  def create
    device_interface = Inventory::DeviceInterfaces::CreateService.new(device: @device, params: device_interface_params).call
    render_data(data: Api::V1::DeviceInterfaceSerializer.new(device_interface).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    device_interface = Inventory::DeviceInterfaces::UpdateService.new(device_interface: @device_interface, params: device_interface_params).call
    render_data(data: Api::V1::DeviceInterfaceSerializer.new(device_interface).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @device_interface.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_record_errors(@device_interface)
  end

  private

  def set_device
    @device = find_record(current_organization.devices, params[:device_id])
  end

  def set_device_interface
    @device_interface = find_record(@device.device_interfaces, params[:id])
  end

  def device_interface_params
    params.require(:device_interface).permit(:name, :interface_type, :description, :enabled, :management, metadata: {})
  end
end
