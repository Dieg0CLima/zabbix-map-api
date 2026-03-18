class Inventory::Devices::CreateService
  def initialize(organization:, params:)
    @organization = organization
    @params = params
  end

  def call
    device = @organization.devices.new(@params)
    device.save!
    device
  end
end
