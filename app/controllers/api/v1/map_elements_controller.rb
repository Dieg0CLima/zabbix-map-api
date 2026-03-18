class Api::V1::MapElementsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_element, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    elements = @network_map.map_elements.includes(:mappable).order(:display_order, :id)
    elements = elements.where(mappable_type: params[:type]) if params[:type].present?

    render json: { data: elements.map { |el| element_payload(el) } }, status: :ok
  end

  def show
    render json: { data: element_payload(@map_element) }, status: :ok
  end

  def create
    map_element = MapElements::Create.new(
      network_map: @network_map,
      payload:     permitted_element_params.to_h.symbolize_keys
    ).call

    render json: { data: element_payload(map_element) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  rescue ArgumentError => e
    render json: { error: { message: e.message } }, status: :unprocessable_entity
  end

  def update
    MapElements::Update.new(
      map_element: @map_element,
      payload:     permitted_element_params.to_h.symbolize_keys
    ).call

    render json: { data: element_payload(@map_element) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    MapElements::Destroy.new(map_element: @map_element).call

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o elemento")
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end

  def set_map_element
    @map_element = @network_map.map_elements.find_by(external_id: params[:id])
    return if @map_element.present?

    @map_element = @network_map.map_elements.find(params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @map_element.blank?
  end

  def permitted_element_params
    params.require(:map_element).permit(
      :mappable_type, :mappable_id, :external_id,
      :lat, :lng,
      :icon_override, :color_override, :label_override, :size_override,
      :collapsed, :display_order,
      metadata: {}
    )
  end

  def element_payload(map_element)
    MapElements::PayloadBuilder.new(map_element:).call
  end
end
