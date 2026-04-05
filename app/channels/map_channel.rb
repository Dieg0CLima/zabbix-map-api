class MapChannel < ApplicationCable::Channel
  def subscribed
    @network_map = find_authorized_map
    return reject unless @network_map

    stream_for @network_map

    transmit({
      type: "initial",
      metrics: build_metrics,
      cable_metrics: build_cable_metrics,
      events: build_events
    })
  end

  def unsubscribed
    stop_all_streams
  end

  # Called by client to request fresh data.
  # Params:
  #   since  - ISO8601 timestamp to fetch events after (optional)
  def refresh(data = {})
    return unless @network_map

    transmit({
      type: "refresh",
      metrics: build_metrics,
      cable_metrics: build_cable_metrics,
      events: build_events(since: data["since"])
    })
  end

  private

  def find_authorized_map
    org_id  = params[:organization_id]
    map_id  = params[:map_id]
    return unless org_id.present? && map_id.present?

    organization = if current_user.admin?
      Organization.find_by(id: org_id)
    else
      current_user.organizations.find_by(id: org_id)
    end

    return unless organization

    organization.network_maps.find_by(id: map_id)
  end

  def build_metrics
    NetworkMaps::MetricsPayloadBuilder.new(network_map: @network_map).call
  end

  def build_cable_metrics
    NetworkMaps::CableMetricsPayloadBuilder.new(network_map: @network_map).call
  end

  def build_events(since: nil)
    NetworkMaps::RecentEventsPayloadBuilder.new(network_map: @network_map, since: since).call
  end
end
