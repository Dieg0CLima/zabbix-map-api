class NetworkCables::EventStateBuilder
  def self.call(cable:)
    {
      label: cable.label,
      status: cable.status,
      cable_type: cable.cable_type,
      metadata: cable.metadata,
      points: cable.network_cable_points.order(:position).pluck(:position, :x, :y)
    }
  end
end
