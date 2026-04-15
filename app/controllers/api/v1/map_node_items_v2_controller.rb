class Api::V1::MapNodeItemsV2Controller < Api::V1::BaseController
  before_action :set_network_map
  before_action :set_map_node
  before_action :set_map_node_item, only: :destroy
  before_action :require_editor_or_admin!, only: %i[create destroy]

  def index
    items = @map_node.map_node_items.includes(zabbix_item: :host).order(:display_order, :id)
    render_data(data: items.map { |i| MapNodeItems::PayloadBuilder.new(map_node_item: i).call })
  end

  def metrics
    items = @map_node.map_node_items.includes(zabbix_item: :host).order(:display_order, :id)
    payload = MapNodeItems::MetricsFetcher.new(
      network_map: @network_map,
      map_node: @map_node,
      items: items
    ).call

    render_data(data: payload)
  end

  def create
    item = MapNodeItems::Create.new(
      map_node: @map_node,
      payload: permitted_params.to_h.symbolize_keys
    ).call
    render_data(data: MapNodeItems::PayloadBuilder.new(map_node_item: item).call, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @map_node_item.destroy!
    render_data(data: nil)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:network_map_id])
  end

  def set_map_node
    return if performed?

    @map_node = find_record(@network_map.map_nodes, params[:node_id])
  end

  def set_map_node_item
    return if performed?

    @map_node_item = @map_node.map_node_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [{ detail: "Record not found" }])
  end

  def permitted_params
    params.require(:node_item).permit(:zabbix_item_id, :alias, :display_order)
  end
end
