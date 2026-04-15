class NetworkCables::Errors::GeometryConflict < NetworkCables::Errors::DomainError
  def initialize(expected_version:, current_version:)
    super(
      code: "geometry_conflict",
      message: "Geometry version conflict",
      details: {
        expected_version: expected_version,
        current_version: current_version
      }
    )
  end
end
