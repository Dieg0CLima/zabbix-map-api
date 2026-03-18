class Inventory::Devices::UpdateService
  def initialize(device:, params:)
    @device = device
    @params = params
  end

  def call
    @device.update!(@params)
    @device
  end
end
