class Api::V1::DeviceObservabilityEventsSerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    @payload
  end
end
