class NetworkCables::PointSetValidator
  def self.validate!(points)
    raise NetworkCables::Errors::InvalidPoints if Array(points).length < 2
  end
end
