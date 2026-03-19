class Api::V1::DeviceObservabilityInterfacesSerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    @payload
  end
end
