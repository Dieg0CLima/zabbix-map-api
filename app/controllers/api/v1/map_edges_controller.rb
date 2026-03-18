class Api::V1::MapEdgesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_network_map
  before_action :set_map_edge, only: %i[update destroy]

  def index
    render_data(data: @network_map.map_edges.order(:id).map { |edge| Api::V1::MapEdgeSerializer.new(edge).as_json })
  end

  def create
    edge = @network_map.map_edges.new(map_edge_params)
    edge.save!
    render_data(data: Api::V1::MapEdgeSerializer.new(edge).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    @map_edge.update!(map_edge_params)
    render_data(data: Api::V1::MapEdgeSerializer.new(@map_edge).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @map_edge.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed
    render_record_errors(@map_edge)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:map_id] || params[:network_map_id])
  end

  def set_map_edge
    @map_edge = find_record(@network_map.map_edges, params[:id])
  end

  def map_edge_params
    params.require(:map_edge).permit(:source_node_id, :target_node_id, :edge_type, :label, :color, metadata: {})
  end
end
