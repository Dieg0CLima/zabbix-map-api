class Api::V1::MapPopsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_pop, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: @network_map.map_pops.order(:id) }, status: :ok
  end

  def show
    render json: { data: @map_pop }, status: :ok
  end

  def create
    map_pop = @network_map.map_pops.new(map_pop_params)

    if map_pop.save
      render json: { data: map_pop }, status: :created
    else
      render json: { errors: map_pop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @map_pop.update(map_pop_params)
      render json: { data: @map_pop }, status: :ok
    else
      render json: { errors: @map_pop.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @map_pop.destroy
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

  def set_map_pop
    @map_pop = @network_map.map_pops.find(params[:id])
  end

  def map_pop_params
    params.require(:map_pop).permit(:name, :external_id, :lat, :lng, :color, metadata: {})
  end
end
