class NetworkCables::Update
  def initialize(cable:, network_map:, payload:, actor_email:, points_provided:)
    @cable = cable
    @payload = payload
    @points_provided = points_provided
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    previous_state = NetworkCables::EventStateBuilder.call(cable: @cable)
    points_changed = false

    ActiveRecord::Base.transaction do
      @cable.update!(@payload.except(:points))

      if @points_provided
        points_changed = replace_points!
        @cable.reload
      end

      current_state = NetworkCables::EventStateBuilder.call(cable: @cable)
      @event_recorder.record!(
        cable: @cable,
        event_type: NetworkCables::EventTypeInferer.infer(previous_state:, current_state:, points_changed:),
        before_state: previous_state,
        after_state: current_state,
        notes: "Cabo atualizado"
      )
    end

    @cable.reload
  end

  private

  def replace_points!
    NetworkCables::PointSetValidator.validate!(@payload[:points])
    normalized_points = NetworkCables::PointNormalizer.normalize(@payload[:points])
    previous_points = NetworkCables::PointNormalizer.normalize(
      @cable.network_cable_points.order(:position).map { |point| { position: point.position, x: point.x, y: point.y } }
    )

    @cable.network_cable_points.destroy_all
    normalized_points.each { |point| @cable.network_cable_points.create!(point) }

    previous_points != normalized_points
  end
end
