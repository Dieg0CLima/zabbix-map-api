class NetworkCables::Errors::InvalidGeometryOperation < NetworkCables::Errors::DomainError
  def initialize(operation:, details: {})
    super(
      code: "invalid_geometry_operation",
      message: "Geometry operation is invalid",
      details: details.merge(operation: operation)
    )
  end
end
