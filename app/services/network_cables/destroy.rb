class NetworkCables::Destroy
  def initialize(cable:, network_map:, actor_email:)
    @cable = cable
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    @event_recorder.record!(
      cable: @cable,
      event_type: "deleted",
      before_state: NetworkCables::EventStateBuilder.call(cable: @cable),
      notes: "Cabo removido"
    )

    @cable.destroy
  end
end
