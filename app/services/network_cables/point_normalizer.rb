class NetworkCables::PointNormalizer
  def self.normalize(points_payload)
    Array(points_payload).map.with_index do |point, index|
      normalize_point(point, index:)
    end
  end

  def self.normalize_point(point, index:)
    p = point.respond_to?(:with_indifferent_access) ? point.with_indifferent_access : point
    x = p[:x].nil? ? p[:lat] : p[:x]
    y = p[:y].nil? ? p[:lng] : p[:y]

    raise ArgumentError, "point coordinates are required" if x.nil? || y.nil?

    {
      position: p[:position] || index,
      x:,
      y:
    }
  end
  private_class_method :normalize_point
end
