class Api::V1::MapElementItemsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_element
  before_action :set_map_element_item, only: :destroy
  before_action :require_editor_or_admin!, only: %i[create destroy]

  def index
    items = @map_element.map_element_items.includes(:zabbix_item).order(:display_order)
    render json: { data: items.map { |i| item_payload(i) } }, status: :ok
  end

  def create
    item = MapElementItems::Create.new(
      map_element: @map_element,
      payload:     permitted_item_params.to_h
    ).call

    render json: { data: item_payload(item) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    MapElementItems::Destroy.new(map_element_item: @map_element_item).call

    head :no_content
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end

  def set_map_element
    @map_element = @network_map.map_elements.find_by(external_id: params[:map_element_id])
    return if @map_element.present?

    @map_element = @network_map.map_elements.find(params[:map_element_id]) if params[:map_element_id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @map_element.blank?
  end

  def set_map_element_item
    @map_element_item = @map_element.map_element_items.find(params[:id])
  end

  def permitted_item_params
    params.require(:map_element_item).permit(:zabbix_item_id, :alias, :display_order)
  end

  def item_payload(item)
    MapElementItems::PayloadBuilder.new(map_element_item: item).call
  end
end
