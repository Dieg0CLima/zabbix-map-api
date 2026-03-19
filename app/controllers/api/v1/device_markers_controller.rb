class Api::V1::DeviceMarkersController < Api::V1::BaseController
  before_action :require_editor_or_admin!
  before_action :set_network_map
  before_action :set_marker, only: %i[update destroy]

  def create
    device = find_record(current_organization.devices, params.require(:device_id))
    return if performed?

    marker = Devices::AttachDeviceToMap.new(network_map: @network_map, device:, params: marker_params, actor: current_user).call
    render_data(data: Api::V1::MapElementSerializer.new(marker).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    marker = Devices::UpdateDeviceMarker.new(map_node: @marker, params: marker_params, actor: current_user).call
    render_data(data: Api::V1::MapElementSerializer.new(marker).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    Devices::DetachDeviceFromMap.new(map_node: @marker).call
    render_data(data: nil)
  end

  def bulk_create
    result = NetworkMaps::BulkAttachDevices.new(network_map: @network_map, items: bulk_items, actor: current_user).call
    render_data(data: result)
  end

  def bulk_update
    result = NetworkMaps::BulkUpdateElements.new(network_map: @network_map, items: bulk_items, actor: current_user).call
    render_data(data: result)
  end

  def bulk_destroy
    result = NetworkMaps::BulkDetachElements.new(network_map: @network_map, ids: params.fetch(:ids, [])).call
    render_data(data: result)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:network_map_id])
  end

  def set_marker
    @marker = find_record(@network_map.map_nodes.where(mappable_type: "Device"), params[:id])
  end

  def marker_params
    position = params[:position] || params.dig(:device_marker, :position) || {}
    {
      x: position[:lng] || position[:x] || params[:x], y: position[:lat] || position[:y] || params[:y],
      lat: position[:lat] || position[:y] || params[:lat], lng: position[:lng] || position[:x] || params[:lng],
      label_override: params[:label_override] || params.dig(:device_marker, :label_override),
      color: params[:color_override] || params.dig(:device_marker, :color_override),
      icon: params[:icon_override] || params.dig(:device_marker, :icon_override),
      metadata: (params[:metadata] || params.dig(:device_marker, :metadata) || {}).merge("locked" => params[:locked] || params.dig(:device_marker, :locked))
    }.compact
  end

  def bulk_items
    params.fetch(:items, []).map { |item| item.to_unsafe_h.symbolize_keys }
  end
end
