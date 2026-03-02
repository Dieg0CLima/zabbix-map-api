class NetworkCables::Update
  def initialize(cable:, network_map:, payload:, actor_email:, points_provided:)
    @cable = cable
    @network_map = network_map
    @payload = payload
    @actor_email = actor_email
    @points_provided = points_provided
  end

  def call
    before_state = event_state_for(@cable)

    ActiveRecord::Base.transaction do
      @cable.update!(@payload.except(:points))
      replace_points! if @points_provided
      @cable.reload

      after_state = event_state_for(@cable)
      record_event!(
        @cable,
        event_type: infer_event_type(before_state, after_state),
        before_state:,
        after_state:,
        notes: "Cabo atualizado"
      )
    end

    @cable.reload
  end

  private

  def replace_points!
    points = Array(@payload[:points])
    if points.length < 2
      @cable.errors.add(:points, "É necessário ao menos 2 pontos")
      raise ActiveRecord::RecordInvalid, @cable
    end

    @cable.network_cable_points.destroy_all

    points.each do |point|
      @cable.network_cable_points.create!(
        position: point[:position],
        x: point[:x] || point[:lat],
        y: point[:y] || point[:lng]
      )
    end
  end

  def infer_event_type(before_state, after_state)
    return "status_changed" if before_state[:status] != after_state[:status]
    return "geometry_changed" if before_state[:points] != after_state[:points]
    return "metadata_updated" if before_state[:metadata] != after_state[:metadata]

    "updated"
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
