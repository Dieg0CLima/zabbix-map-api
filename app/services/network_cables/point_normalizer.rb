class NetworkCables::PointNormalizer
  def self.normalize(point, index: nil)
    {
      position: point[:position] || index,
      x: point[:x] || point[:lat],
      y: point[:y] || point[:lng]
    }
  end

  def self.normalize_set(points)
    Array(points).map.with_index { |point, index| normalize(point, index:) }
  end
end
