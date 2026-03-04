class Api::V1::NetworkCablesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    cables = apply_filters(@network_map.network_cables.includes(:network_cable_points)).order(:id)

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

  private


  def render_domain_error(error)
    render json: {
      error: {
        code: error.code,
        message: error.message,
        details: error.details
      }
    }, status: :unprocessable_entity
  end

  def set_network_map
    maps_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @network_map = maps_scope.find(params[:network_map_id])
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
      :label,
      :cable_type,
      :status,
      :color,
      :weight,
      :pattern,
      :bandwidth_mbps,
      :length_meters,
      metadata: {},
      points: [:position, :x, :y, :lat, :lng]
    )
  end

  def cable_payload(cable)
    NetworkCables::PayloadBuilder.new(cable:).call
  end

  def apply_filters(scope)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(cable_type: params[:cable_type]) if params[:cable_type].present?

    if params[:network_role].present?
      scope = scope.where("metadata ->> 'network_role' = ?", params[:network_role])
    end

    scope = scope.where(source_pop_id: resolve_pop_filter(params[:source_pop_id])) if params[:source_pop_id].present?
    scope = scope.where(target_pop_id: resolve_pop_filter(params[:target_pop_id])) if params[:target_pop_id].present?

    if params[:q].present?
      query = "%#{params[:q]}%"
      scope = scope.where("label ILIKE ? OR metadata ->> 'code' ILIKE ?", query, query)
    end

    if params[:fiber_count_min].present?
      scope = scope.where("(metadata ->> 'fiber_count')::int >= ?", params[:fiber_count_min].to_i)
    end

    if params[:fiber_count_max].present?
      scope = scope.where("(metadata ->> 'fiber_count')::int <= ?", params[:fiber_count_max].to_i)
    end

    scope
  end

  def resolve_pop_filter(value)
    return value if value.to_s.match?(/\A\d+\z/)

    @network_map.map_pops.find_by(external_id: value)&.id
  end
end
