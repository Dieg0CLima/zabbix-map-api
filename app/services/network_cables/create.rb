class NetworkCables::Create
  def initialize(network_map:, payload:, actor_email:)
    @network_map = network_map
    @payload = payload
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    NetworkCables::PointSetValidator.validate!(@payload[:points])

    cable = @network_map.network_cables.new(@payload.except(:points))
    points = NetworkCables::PointNormalizer.normalize(@payload[:points])

    ActiveRecord::Base.transaction do
      cable.save!
      CableFusion::LoadDiagram.new(cable:).call
      create_points!(cable, points)
      @event_recorder.record!(
        cable:,
        event_type: "created",
        after_state: NetworkCables::EventStateBuilder.call(cable:),
        notes: "Cabo criado"
      )
    end

    cable.reload
  end

  private

  def create_points!(cable, points)
    points.each do |point|
      cable.network_cable_points.create!(point)
    end
  end
end
