class Api::V1::NetworkMapMonitoringController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map

  def show
    payload = NetworkMaps::MonitoringPayloadBuilder.new(network_map: @network_map).call
    render json: { data: payload }, status: :ok
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:network_map_id])
  end
end
