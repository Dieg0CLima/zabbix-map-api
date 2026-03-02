class NetworkCables::Destroy
  def initialize(cable:, network_map:, actor_email:)
    @cable = cable
    @network_map = network_map
    @actor_email = actor_email
  end

  def call
    record_event!(
      @cable,
      event_type: "deactivated",
      before_state: event_state_for(@cable),
      notes: "Cabo removido"
    )

    @cable.destroy
  end

  private

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
