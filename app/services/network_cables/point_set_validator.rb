class NetworkCables::PointSetValidator
  MIN_POINTS = 2

  def self.validate!(points)
    provided_points = Array(points).length

    if points.nil? || points == []
      raise NetworkCables::Errors::InvalidPoints.new(
        provided_points:,
        reason: "points_blank"
      )
    end

    return if provided_points >= MIN_POINTS

    raise NetworkCables::Errors::InvalidPoints.new(
      provided_points:,
      reason: "too_few_points"
    )
  end
end
