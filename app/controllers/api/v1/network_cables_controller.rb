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
    points = points_params
    return render_validation_error(points: "É necessário ao menos 2 pontos") if points.length < 2

    cable = @network_map.network_cables.new(network_cable_params)

    ActiveRecord::Base.transaction do
      cable.save!
      upsert_points!(cable)
      record_event!(cable, event_type: "created", after_state: event_state_for(cable), notes: "Cabo criado")
    end

    render json: { data: cable_payload(cable.reload) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    before_state = event_state_for(@network_cable)

    ActiveRecord::Base.transaction do
      @network_cable.update!(network_cable_params)
      replace_points!(@network_cable)
      @network_cable.reload

      record_event!(
        @network_cable,
        event_type: infer_event_type(before_state, event_state_for(@network_cable)),
        before_state:,
        after_state: event_state_for(@network_cable),
        notes: "Cabo atualizado"
      )
    end

    render json: { data: cable_payload(@network_cable.reload) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    record_event!(@network_cable, event_type: "deactivated", before_state: event_state_for(@network_cable), notes: "Cabo removido")
    @network_cable.destroy

    head :no_content
  end

  private

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

  def network_cable_params
    params.require(:network_cable).permit(
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

  def points_params
    Array(params.fetch(:network_cable, {}).fetch(:points, []))
  end

  def upsert_points!(cable)
    points_params.each do |point|
      point_data = point.permit(:position, :x, :y, :lat, :lng)
      cable.network_cable_points.create!(
        position: point_data[:position],
        x: point_data[:x] || point_data[:lat],
        y: point_data[:y] || point_data[:lng]
      )
    end
  end

  def replace_points!(cable)
    return unless params.fetch(:network_cable, {}).key?(:points)

    points = points_params
    if points.length < 2
      cable.errors.add(:points, "É necessário ao menos 2 pontos")
      raise ActiveRecord::RecordInvalid, cable
    end

    cable.network_cable_points.destroy_all
    upsert_points!(cable)
  end

  def cable_payload(cable)
    {
      id: cable.id,
      external_id: cable.external_id,
      network_map_id: cable.network_map_id,
      source_pop_id: cable.source_pop&.external_id || cable.source_pop_id,
      target_pop_id: cable.target_pop&.external_id || cable.target_pop_id,
      source_node_id: cable.source_node&.external_id || cable.source_node_id,
      target_node_id: cable.target_node&.external_id || cable.target_node_id,
      label: cable.label,
      cable_type: cable.cable_type,
      status: cable.status,
      color: cable.color,
      weight: cable.weight,
      pattern: cable.pattern,
      bandwidth_mbps: cable.bandwidth_mbps,
      length_meters: cable.length_meters,
      metadata: cable.metadata,
      points: cable.network_cable_points.order(:position).map do |point|
        {
          id: point.id,
          position: point.position,
          x: point.x,
          y: point.y,
          lat: point.x,
          lng: point.y
        }
      end
    }
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

  def infer_event_type(before_state, after_state)
    return "status_changed" if before_state[:status] != after_state[:status]
    return "geometry_changed" if before_state[:points] != after_state[:points]
    return "metadata_updated" if before_state[:metadata] != after_state[:metadata]

    "updated"
  end

  def event_state_for(cable)
    {
      label: cable.label,
      status: cable.status,
      cable_type: cable.cable_type,
      metadata: cable.metadata,
      points: cable.network_cable_points.order(:position).pluck(:position, :x, :y)
    }
  end

  def record_event!(cable, event_type:, before_state: nil, after_state: nil, notes: nil)
    cable.network_cable_events.create!(
      network_map: @network_map,
      event_type:,
      occurred_at: Time.current,
      actor: current_user.email,
      before_state: before_state || {},
      after_state: after_state || {},
      notes:
    )
  end
end
