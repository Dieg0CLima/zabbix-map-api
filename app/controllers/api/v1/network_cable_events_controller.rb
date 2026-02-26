class Api::V1::NetworkCableEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable

  def index
    events = @network_cable.network_cable_events.order(occurred_at: :desc, id: :desc)

    render json: {
      data: events.map do |event|
        {
          id: event.id,
          cable_id: event.network_cable&.external_id || event.network_cable_id,
          event_type: event.event_type,
          timestamp: event.occurred_at,
          actor: event.actor,
          before: event.before_state,
          after: event.after_state,
          notes: event.notes
        }
      end
    }, status: :ok
  end

  private

  def set_network_map
    maps_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @network_map = maps_scope.find(params[:network_map_id])
  end

  def set_network_cable
    @network_cable = @network_map.network_cables.find(params[:network_cable_id])
  end
end
