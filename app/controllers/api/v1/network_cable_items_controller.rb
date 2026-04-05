class Api::V1::NetworkCableItemsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable
  before_action :set_network_cable_item, only: :destroy
  before_action :require_editor_or_admin!, only: %i[create destroy]

  def index
    items = @network_cable.network_cable_items.includes(:zabbix_item).order(:display_order, :id)
    render json: { data: items.map { |i| NetworkCableItems::PayloadBuilder.new(network_cable_item: i).call } }, status: :ok
  end

  def create
    item = NetworkCableItems::Create.new(
      network_cable: @network_cable,
      payload: permitted_params.to_h.symbolize_keys
    ).call

    render json: { data: NetworkCableItems::PayloadBuilder.new(network_cable_item: item).call }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    NetworkCableItems::Destroy.new(network_cable_item: @network_cable_item).call
    head :no_content
  end

  private

  def set_network_map
    id = params[:legacy_network_map_id] || params[:network_map_id]
    @network_map = scoped_network_maps.find(id)
  end

  def set_network_cable
    @network_cable = @network_map.network_cables.find(params[:network_cable_id])
  end

  def set_network_cable_item
    @network_cable_item = @network_cable.network_cable_items.find(params[:id])
  end

  def permitted_params
    params.require(:network_cable_item).permit(:zabbix_item_id, :alias, :metric_role, :display_order)
  end
end
