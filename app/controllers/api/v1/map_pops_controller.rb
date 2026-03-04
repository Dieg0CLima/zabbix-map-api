class Api::V1::MapPopsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_pop, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    pops = @network_map.map_pops.order(:id)
    render json: { data: pops.map { |pop| map_pop_payload(pop) } }, status: :ok
  end

  def show
    render json: { data: map_pop_payload(@map_pop) }, status: :ok
  end

  def create
    map_pop = @network_map.map_pops.create!(permitted_map_pop_payload.to_h)

    render json: { data: map_pop_payload(map_pop) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    @map_pop.update!(permitted_map_pop_payload.to_h)

    render json: { data: map_pop_payload(@map_pop) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    if @map_pop.destroy
      head :no_content
    else
      render_validation_error(@map_pop, message: "Não foi possível remover o POP")
    end
  end

  private

  def set_network_map
    @network_map = network_maps_scope.find(params[:network_map_id])
  end

  def network_maps_scope
    admin_without_organization_context? ? NetworkMap : current_organization.network_maps
  end

  def set_map_pop
    @map_pop = @network_map.map_pops.find_by(external_id: params[:id])
    return if @map_pop.present?

    @map_pop = @network_map.map_pops.find(params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @map_pop.blank?
  end

  def permitted_map_pop_payload
    params.require(:map_pop).permit(:name, :external_id, :lat, :lng, :color, metadata: {})
  end

  def map_pop_payload(pop)
    MapPops::PayloadBuilder.new(pop:).call
  end
end
