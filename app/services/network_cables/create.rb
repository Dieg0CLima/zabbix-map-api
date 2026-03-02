class NetworkCables::Create
  def initialize(network_map:, payload:, actor_email:)
    @network_map = network_map
    @payload = payload
    @actor_email = actor_email
  end

  def call
    validate_points!(@payload[:points])
    cable = @network_map.network_cables.new(@payload.except(:points))

    ActiveRecord::Base.transaction do
      cable.save!
      create_points!(cable, @payload[:points])
      record_event!(cable, event_type: "created", after_state: event_state_for(cable), notes: "Cabo criado")
    end

    cable.reload
  end

  private

  def validate_points!(points)
    return if Array(points).length >= 2

    raise ActiveRecord::RecordInvalid.new(build_error_record(points: "É necessário ao menos 2 pontos"))
  end

  def create_points!(cable, points)
    Array(points).each do |point|
      cable.network_cable_points.create!(
        position: point[:position],
        x: point[:x] || point[:lat],
        y: point[:y] || point[:lng]
      )
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

  def build_error_record(details)
    NetworkCable.new.tap do |record|
      details.each { |field, message| record.errors.add(field, message) }
    end
  end
end
