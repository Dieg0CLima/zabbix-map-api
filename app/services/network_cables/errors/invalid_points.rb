class NetworkCables::Errors::InvalidPoints < NetworkCables::Errors::DomainError
  def initialize(provided_points:, reason:)
    super(
      code: "invalid_points",
      message: "Points payload is invalid",
      details: {
        min_points: 2,
        provided_points:,
        reason:
      }
    )
  end
end
