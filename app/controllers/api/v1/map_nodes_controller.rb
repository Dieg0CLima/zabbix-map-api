class Api::V1::MapNodesController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_map_node, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    nodes = @network_map.map_nodes.includes(:map_pop).order(:id)
    render json: { data: nodes.map { |node| map_node_payload(node) } }, status: :ok
  end

  def show
    render json: { data: map_node_payload(@map_node) }, status: :ok
  end

  def create
    map_node = MapNodes::Create.new(
      network_map: @network_map,
      payload: permitted_map_node_payload.to_h.symbolize_keys
    ).call

    render json: { data: map_node_payload(map_node) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    map_node = MapNodes::Update.new(
      map_node: @map_node,
      payload: permitted_map_node_payload.to_h.symbolize_keys
    ).call

    render json: { data: map_node_payload(map_node) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    MapNodes::Destroy.new(map_node: @map_node).call

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o nó")
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end

  def set_map_node
    @map_node = @network_map.map_nodes.find_by(external_id: params[:id])
    return if @map_node.present?

    @map_node = @network_map.map_nodes.includes(:map_pop).find(params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @map_node.blank?
  end

  def permitted_map_node_payload
    @permitted_map_node_payload ||= params.require(:map_node).permit(
      :external_id,
      :map_pop_id,
      :label,
      :node_kind,
      :x,
      :y,
      :lat,
      :lng,
      :icon,
      :color,
      :size,
      :zabbix_ref,
      :device_id,
      metadata: {}
    )
  end

  def map_node_payload(map_node)
    MapNodes::PayloadBuilder.new(map_node:).call
  end
end
