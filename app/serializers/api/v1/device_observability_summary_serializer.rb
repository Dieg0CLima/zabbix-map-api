class Api::V1::DeviceObservabilitySummarySerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    @payload
  end
end
