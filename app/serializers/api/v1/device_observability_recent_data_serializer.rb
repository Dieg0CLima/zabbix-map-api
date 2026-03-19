class Api::V1::DeviceObservabilityRecentDataSerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    @payload
  end
end
