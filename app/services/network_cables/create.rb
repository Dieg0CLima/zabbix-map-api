class NetworkCables::Create
  def initialize(network_map:, payload:, actor_email:)
    @network_map = network_map
    @payload = payload
    @actor_email = actor_email
  end

  def call
    NetworkCables::PointSetValidator.validate!(@payload[:points])

    cable = @network_map.network_cables.new(@payload.except(:points))
    points = NetworkCables::PointNormalizer.normalize_set(@payload[:points])

    ActiveRecord::Base.transaction do
      cable.save!
      create_points!(cable, points)
      record_event!(cable, event_type: "created", after_state: event_state_for(cable), notes: "Cabo criado")
    end

    cable.reload
  end

  private

  def create_points!(cable, points)
    points.each do |point|
      cable.network_cable_points.create!(point)
    end
  end

  def event_state_for(cable)
    {
      label: cable.label,
      status: cable.status,
      cable_type: cable.cable_type,
      metadata: cable.metadata,
      points: cable.network_cable_points.order(:position).pluck(:position, :x, :y)
    }
  end

  def record_event!(cable, event_type:, before_state: nil, after_state: nil, notes: nil)
    cable.network_cable_events.create!(
      network_map: @network_map,
      event_type:,
      occurred_at: Time.current,
      actor: @actor_email,
      before_state: before_state || {},
      after_state: after_state || {},
      notes:
    )
  end
end
