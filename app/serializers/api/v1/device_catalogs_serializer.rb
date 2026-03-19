class Api::V1::DeviceCatalogsSerializer
  def initialize(payload)
    @payload = payload
  end

  def as_json(*)
    {
      roles: serialize_options(@payload[:roles]),
      statuses: serialize_options(@payload[:statuses])
    }
  end

  private

  def serialize_options(options)
    Array(options).map do |option|
      {
        value: option[:value],
        label: option[:label]
      }
    end
  end
end
