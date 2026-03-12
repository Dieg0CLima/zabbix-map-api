class Api::V1::MapNodeItemsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_node
  before_action :set_map_node_item, only: :destroy
  before_action :require_editor_or_admin!, only: %i[create destroy]

  def index
    items = @map_node.map_node_items.includes(:zabbix_item).order(:display_order, :id)
    render json: { data: items.map { |i| MapNodeItems::PayloadBuilder.new(map_node_item: i).call } }, status: :ok
  end

  def create
    item = MapNodeItems::Create.new(
      map_node: @map_node,
      payload: permitted_params.to_h.symbolize_keys
    ).call

    render json: { data: MapNodeItems::PayloadBuilder.new(map_node_item: item).call }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    MapNodeItems::Destroy.new(map_node_item: @map_node_item).call
    head :no_content
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end

  def set_map_node
    @map_node = @network_map.map_nodes.find_by(external_id: params[:map_node_id])

    if @map_node.blank? && params[:map_node_id].to_s.match?(/\A\d+\z/)
      @map_node = @network_map.map_nodes.find_by(id: params[:map_node_id])
    end

    raise ActiveRecord::RecordNotFound if @map_node.blank?
  end

  def set_map_node_item
    @map_node_item = @map_node.map_node_items.find(params[:id])
  end

  def permitted_params
    params.require(:map_node_item).permit(:zabbix_item_id, :alias, :display_order)
  end
end
