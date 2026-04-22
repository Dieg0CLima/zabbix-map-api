class Api::V1::NetworkCablesController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable, only: %i[show update destroy available_device_items geometry]
  before_action :require_editor_or_admin!, only: %i[create update destroy geometry]

  def index
    cables = NetworkCables::FilterQuery.new(
      scope: @network_map.network_cables.includes(:network_cable_points),
      params: filter_params,
      network_map: @network_map
    ).call.order(:id)

    render json: { data: cables.map { |cable| cable_payload(cable) } }, status: :ok
  end

  def show
    render json: { data: cable_payload(@network_cable) }, status: :ok
  end

  def create
    cable = NetworkCables::Create.new(
      network_map: @network_map,
      payload: permitted_network_cable_payload.to_h.symbolize_keys,
      actor_email: current_user.email
    ).call

    render json: { data: cable_payload(cable) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  rescue NetworkCables::Errors::DomainError => e
    render_domain_error(e)
  end

  def update
    cable = NetworkCables::Update.new(
      cable: @network_cable,
      network_map: @network_map,
      payload: permitted_network_cable_payload.to_h.symbolize_keys,
      actor_email: current_user.email,
      points_provided: params.fetch(:network_cable, {}).key?(:points)
    ).call

    render json: { data: cable_payload(cable) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  rescue NetworkCables::Errors::DomainError => e
    render_domain_error(e)
  end

  def destroy
    NetworkCables::Destroy.new(cable: @network_cable, network_map: @network_map, actor_email: current_user.email).call

    head :no_content
  end

  def geometry
    cable = NetworkCables::EditGeometry.new(
      cable: @network_cable,
      network_map: @network_map,
      payload: geometry_payload.to_h.symbolize_keys,
      actor_email: current_user.email
    ).call

    render json: { data: cable_payload(cable) }, status: :ok
  rescue NetworkCables::Errors::GeometryConflict => e
    render json: {
      code: e.code,
      message: e.message,
      details: e.details
    }, status: :conflict
  rescue NetworkCables::Errors::DomainError => e
    render_domain_error(e)
  end

  def available_device_items
    result = NetworkCables::AvailableDeviceItemsQuery.new(cable: @network_cable).call
    render json: { data: result }, status: :ok
  end

  private

  def set_network_map
    id = params[:legacy_network_map_id] || params[:network_map_id]
    @network_map = scoped_network_maps.find(id)
  end

  def set_network_cable
    @network_cable = @network_map.network_cables.includes(:network_cable_points).find(params[:id])
  end

  def permitted_network_cable_payload
    @permitted_network_cable_payload ||= params.require(:network_cable).permit(
      :external_id,
      :source_pop_id,
      :target_pop_id,
      :source_node_id,
      :target_node_id,
      :source_site_id,
      :target_site_id,
      :source_element_id,
      :target_element_id,
      :label,
      :cable_type,
      :status,
      :color,
      :weight,
      :pattern,
      :bandwidth_mbps,
      :length_meters,
      metadata: {},
      points: [ :position, :x, :y, :lat, :lng ]
    )
  end

  def filter_params
    params.permit(:status, :cable_type, :network_role, :source_pop_id, :target_pop_id, :q, :fiber_count_min, :fiber_count_max)
  end

  def geometry_payload
    params.require(:geometry).permit(
      :operation,
      :geometry_version,
      :side,
      :pop_id,
      :site_id,
      :position,
      :after_position,
      :from_position,
      :to_position,
      point: [ :x, :y, :lat, :lng ],
      points: [ :position, :x, :y, :lat, :lng ]
    )
  end

  def cable_payload(cable)
    NetworkCables::PayloadBuilder.new(cable:).call
  end
end
