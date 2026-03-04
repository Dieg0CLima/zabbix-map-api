module NetworkCableEvents
  class PayloadBuilder
    def initialize(event:)
      @event = event
    end

    def call
      {
        id: @event.id,
        cable_id: @event.network_cable&.external_id || @event.network_cable_id,
        event_type: @event.event_type,
        timestamp: @event.occurred_at&.iso8601,
        actor: @event.actor,
        before: @event.before_state.presence || {},
        after: @event.after_state.presence || {},
        notes: @event.notes
      }
    end
  end
end
