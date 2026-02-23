class Api::V1::NetworkCablesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    cables = @network_map.network_cables.includes(:network_cable_points).order(:id)

    render json: { data: cables.map { |cable| cable_payload(cable) } }, status: :ok
  end

  def show
    render json: { data: cable_payload(@network_cable) }, status: :ok
  end

  def create
    cable = @network_map.network_cables.new(network_cable_params)

    ActiveRecord::Base.transaction do
      cable.save!
      upsert_points!(cable)
    end

    render json: { data: cable_payload(cable.reload) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      @network_cable.update!(network_cable_params)
      replace_points!(@network_cable)
    end

    render json: { data: cable_payload(@network_cable.reload) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
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
      metadata: {}
    )
  end

  def points_params
    params.fetch(:network_cable, {}).fetch(:points, [])
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

    cable.network_cable_points.destroy_all
    upsert_points!(cable)
  end

  def cable_payload(cable)
    {
      id: cable.external_id || cable.id,
      network_map_id: cable.network_map_id,
      source_pop_id: cable.source_pop&.external_id || cable.source_pop_id,
      target_pop_id: cable.target_pop&.external_id || cable.target_pop_id,
      source_node_id: cable.source_node_id,
      target_node_id: cable.target_node_id,
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
end
