class NetworkCables::EventRecorder
  def initialize(network_map:, actor_email:)
    @network_map = network_map
    @actor_email = actor_email
  end

  def record!(cable:, event_type:, before_state: nil, after_state: nil, notes: nil)
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
