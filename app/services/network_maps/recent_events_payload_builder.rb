class NetworkMaps::RecentEventsPayloadBuilder
  DEFAULT_LIMIT = 50

  def initialize(network_map:, since: nil, limit: DEFAULT_LIMIT)
    @network_map = network_map
    @since = since
    @limit = limit
  end

  def call
    {
      network_map_id: @network_map.id,
      collected_at: Time.current,
      cable_events: cable_events_data
    }
  end

  private

  def cable_events_data
    scope = @network_map.network_cable_events
                        .includes(:network_cable)
                        .order(occurred_at: :desc)
                        .limit(@limit)

    if @since.present?
      since_time = Time.zone.parse(@since.to_s) rescue nil
      scope = scope.where("occurred_at > ?", since_time) if since_time
    end

    scope.map { |e| build_event_data(e) }
  end

  def build_event_data(event)
    {
      id: event.id,
      cable_id: event.network_cable&.external_id || event.network_cable_id,
      event_type: event.event_type,
      occurred_at: event.occurred_at,
      actor: event.actor,
      notes: event.notes
    }
  end
end
