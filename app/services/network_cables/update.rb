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

    points.each do |point|
      @cable.network_cable_points.create!(point)
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
