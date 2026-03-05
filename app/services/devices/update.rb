class Devices::Update
  def initialize(device:, payload:)
    @device = device
    @payload = payload
  end

  def call
    @device.update!(@payload)
    @device
  end
end
