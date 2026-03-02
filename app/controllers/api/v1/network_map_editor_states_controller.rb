class Api::V1::NetworkMapEditorStatesController < ApplicationController
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
    maps_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @network_map = maps_scope.includes(:map_pops, map_nodes: :map_pop, network_cables: :network_cable_points).find(params[:network_map_id])
  end

  def editor_state_params
    params.require(:editor_state).permit(
      :active_base_layer,
      :history_label,
      :history_index,
      draft_cable: {},
      pops: [ :id, :name, :lat, :lng, :color, { metadata: {} } ],
      markers: [ :id, :label, :node_kind, :lat, :lng, :icon, :color, :size, :zabbix_ref, :pop_id, { metadata: {} } ],
      edges: [ :id, :label, :cable_type, :status, :color, :weight, :pattern, :source_pop_id, :target_pop_id, :source_node_id, :target_node_id,
               { metadata: {} }, { points: [ :position, :lat, :lng ] } ]
    )
  end

  def editor_payload(network_map)
    NetworkMaps::EditorStatePayloadBuilder.new(network_map:).call
  end
end
