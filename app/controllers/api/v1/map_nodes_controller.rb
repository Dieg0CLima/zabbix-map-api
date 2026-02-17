class Api::V1::MapNodesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_node, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: @network_map.map_nodes.order(:id) }, status: :ok
  end

  def show
    render json: { data: @map_node }, status: :ok
  end

  def create
    map_node = @network_map.map_nodes.new(map_node_params)

    if map_node.save
      render json: { data: map_node }, status: :created
    else
      render json: { errors: map_node.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @map_node.update(map_node_params)
      render json: { data: @map_node }, status: :ok
    else
      render json: { errors: @map_node.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @map_node.destroy

    head :no_content
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

  def set_map_node
    @map_node = @network_map.map_nodes.find(params[:id])
  end

  def map_node_params
    params.require(:map_node).permit(:label, :node_kind, :x, :y, :zabbix_ref, metadata: {})
  end
end
