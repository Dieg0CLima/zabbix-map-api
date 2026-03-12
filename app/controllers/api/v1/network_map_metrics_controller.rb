class Api::V1::NetworkMapMetricsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map

  def show
    metrics = NetworkMaps::MetricsPayloadBuilder.new(network_map: @network_map).call
    render json: { data: metrics }, status: :ok
  end

  def events
    since = params[:since]
    limit = params[:limit]&.to_i || NetworkMaps::RecentEventsPayloadBuilder::DEFAULT_LIMIT
    events_data = NetworkMaps::RecentEventsPayloadBuilder.new(
      network_map: @network_map,
      since: since,
      limit: limit
    ).call
    render json: { data: events_data }, status: :ok
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end
end
