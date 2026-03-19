class Inventory::DeviceInterfaces::CreateService
  def initialize(device:, params:)
    @device = device
    @params = params
  end

  def call
    device_interface = @device.device_interfaces.new(@params)
    device_interface.save!
    device_interface
  end
end
