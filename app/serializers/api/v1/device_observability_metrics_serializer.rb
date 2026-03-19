class Api::V1::DeviceObservabilityMetricsSerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    @payload
  end
end
