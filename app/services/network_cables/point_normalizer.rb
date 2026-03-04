class NetworkCables::PointNormalizer
  def self.normalize(points_payload)
    Array(points_payload).map.with_index do |point, index|
      normalize_point(point, index:)
    end
  end

  def self.normalize_point(point, index:)
    x = point[:x].nil? ? point[:lat] : point[:x]
    y = point[:y].nil? ? point[:lng] : point[:y]

    raise ArgumentError, "point coordinates are required" if x.nil? || y.nil?

    {
      position: point[:position] || index,
      x:,
      y:
    }
  end
  private_class_method :normalize_point
end
