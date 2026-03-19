class Inventory::DeviceInterfaces::UpdateService
  def initialize(device_interface:, params:)
    @device_interface = device_interface
    @params = params
  end

  def call
    @device_interface.update!(@params)
    @device_interface
  end
end
