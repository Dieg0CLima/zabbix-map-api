class NetworkCables::Update
  def initialize(cable:, network_map:, payload:, actor_email:, points_provided:)
    @cable = cable
    @payload = payload
    @points_provided = points_provided
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    before_state = NetworkCables::EventStateBuilder.call(cable: @cable)

    ActiveRecord::Base.transaction do
      @cable.update!(@payload.except(:points))
      replace_points! if @points_provided
      @cable.reload

      after_state = NetworkCables::EventStateBuilder.call(cable: @cable)
      @event_recorder.record!(
        cable: @cable,
        event_type: NetworkCables::EventTypeInferer.call(before_state:, after_state:),
        before_state:,
        after_state:,
        notes: "Cabo atualizado"
      )
    end

    @cable.reload
  end

  private

  def replace_points!
    NetworkCables::PointSetValidator.validate!(@payload[:points])
    points = NetworkCables::PointNormalizer.normalize_set(@payload[:points])

    @cable.network_cable_points.destroy_all
    points.each { |point| @cable.network_cable_points.create!(point) }
  end
end
