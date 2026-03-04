class Api::V1::NetworkCableEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable

  def index
    render json: { data: ordered_events.map { |event| event_payload(event) } }, status: :ok
  end

  private

  def event_payload(event)
    NetworkCableEvents::PayloadBuilder.new(event:).call
  end

  def set_network_map
    @network_map = network_maps_scope.find(params[:network_map_id])
  end

  def set_network_cable
    @network_cable = @network_map.network_cables.find(params[:network_cable_id])
  end

  def network_maps_scope
    admin_without_organization_context? ? NetworkMap : current_organization.network_maps
  end

  def ordered_events
    @network_cable.network_cable_events.order(occurred_at: :desc, id: :desc)
  end
end
