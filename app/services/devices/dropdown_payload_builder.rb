class Devices::DropdownPayloadBuilder
  def initialize(device)
    @device = device
  end

  def call
    {
      value: @device.id,
      label: @device.name,
      code: @device.hostname || @device.id.to_s,
      meta: {
        site_id: @device.site_id,
        role: @device.role,
        status: @device.status
      }
    }
  end
end
