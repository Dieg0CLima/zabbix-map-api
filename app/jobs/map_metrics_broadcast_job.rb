class MapMetricsBroadcastJob < ApplicationJob
  queue_as :default

  # Broadcasts current metrics and recent events to all subscribers of a map.
  # Can be enqueued after model mutations or via a scheduler for periodic updates.
  #
  # Example — schedule every 30s from a recurring job:
  #   MapMetricsBroadcastJob.perform_later(map_id)
  #
  def perform(map_id)
    network_map = NetworkMap.find_by(id: map_id)
    return unless network_map

    metrics = NetworkMaps::MetricsPayloadBuilder.new(network_map: network_map).call
    events  = NetworkMaps::RecentEventsPayloadBuilder.new(network_map: network_map).call

    MapChannel.broadcast_to(network_map, {
      type: "broadcast",
      metrics: metrics,
      events: events
    })
  end
end
