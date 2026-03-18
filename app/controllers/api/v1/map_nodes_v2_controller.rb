class Api::V1::MapNodesV2Controller < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy from_site from_device]
  before_action :set_network_map
  before_action :set_map_node, only: %i[update destroy]

  def index
    render_data(data: @network_map.map_nodes.order(:id).map { |node| Api::V1::MapNodeSerializer.new(node).as_json })
  end

  def create
    mappable = find_mappable(params.require(:map_node)[:mappable_type], params.require(:map_node)[:mappable_id])
    return if performed?

    map_node = Inventory::MapNodes::AttachMappableService.new(network_map: @network_map, mappable:, params: map_node_params).call
    render_data(data: Api::V1::MapNodeSerializer.new(map_node).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    map_node = Inventory::MapNodes::UpdateLayoutService.new(map_node: @map_node, params: map_node_params.except(:mappable_type, :mappable_id)).call
    render_data(data: Api::V1::MapNodeSerializer.new(map_node).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @map_node.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_record_errors(@map_node)
  end

  def from_site
    site = find_record(current_organization.sites, params.require(:site_id))
    return if performed?

    map_node = Inventory::MapNodes::AttachMappableService.new(network_map: @network_map, mappable: site, params: map_node_params).call
    render_data(data: Api::V1::MapNodeSerializer.new(map_node).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def from_device
    device = find_record(current_organization.devices, params.require(:device_id))
    return if performed?

    map_node = Inventory::MapNodes::AttachMappableService.new(network_map: @network_map, mappable: device, params: map_node_params).call
    render_data(data: Api::V1::MapNodeSerializer.new(map_node).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:map_id] || params[:network_map_id])
  end

  def set_map_node
    @map_node = find_record(@network_map.map_nodes, params[:id])
  end

  def find_mappable(type, id)
    case type
    when "Site" then find_record(current_organization.sites, id)
    when "Device" then find_record(current_organization.devices, id)
    else
      render_errors(status: :unprocessable_entity, errors: [{ source: :mappable_type, detail: "Unsupported mappable type" }])
      nil
    end
  end

  def map_node_params
    params.fetch(:map_node, ActionController::Parameters.new).permit(:mappable_type, :mappable_id, :x, :y, :width, :height, :label_override, :color, :icon, :visible, :collapsed, :lat, :lng, metadata: {}).to_h.symbolize_keys
  end
end
