class Api::V1::NetworkMapEditorStatesController < ApplicationController
  include EditorStateParams

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :require_editor_or_admin!, only: :update

  def show
    render json: { data: editor_payload(@network_map) }, status: :ok
  end

  def update
    network_map = NetworkMaps::PersistEditorState.new(network_map: @network_map, payload: editor_state_params).call

    render json: { data: editor_payload(network_map) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  private

  def set_network_map
    @network_map = network_maps_scope.includes(:map_pops, map_nodes: :map_pop, network_cables: :network_cable_points).find(params[:network_map_id])
  end

  def network_maps_scope
    admin_without_organization_context? ? NetworkMap : current_organization.network_maps
  end

  def editor_payload(network_map)
    NetworkMaps::EditorStatePayloadBuilder.new(network_map:).call
  end
end
