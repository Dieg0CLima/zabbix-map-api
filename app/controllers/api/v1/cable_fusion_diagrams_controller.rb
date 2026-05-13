class Api::V1::CableFusionDiagramsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :set_network_cable
  before_action :require_editor_or_admin!, only: %i[update validate publish restore_snapshot]

  def show
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    render json: { data: CableFusion::PayloadBuilder.new(diagram:).call }, status: :ok
  end

  def update
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    diagram, validation = CableFusion::PersistDraft.new(diagram:, payload: fusion_diagram_payload, actor: current_user).call

    render json: { data: CableFusion::PayloadBuilder.new(diagram:, validation:).call }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def validate
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    validation = CableFusion::ValidateDraft.new(diagram:).call

    diagram.update!(
      status: validation.valid? ? "draft" : "invalid",
      last_validated_at: Time.current,
      validation_errors_count: validation.errors.size
    )

    render json: { data: CableFusion::PayloadBuilder.new(diagram: diagram.reload, validation:).call }, status: :ok
  end

  def publish
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    diagram, validation = CableFusion::PublishDiagram.new(
      diagram:,
      actor: current_user,
      reason: params[:reason]
    ).call

    render json: { data: CableFusion::PayloadBuilder.new(diagram:, validation:).call }, status: :ok
  end

  def snapshots
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    data = diagram.snapshots.order(version: :desc, id: :desc).map do |snapshot|
      {
        id: snapshot.id,
        version: snapshot.version,
        published: snapshot.published,
        reason: snapshot.reason,
        created_at: snapshot.created_at,
        created_by_user_id: snapshot.created_by_user_id
      }
    end

    render json: { data: data }, status: :ok
  end

  def restore_snapshot
    diagram = CableFusion::LoadDiagram.new(cable: @network_cable).call
    snapshot = diagram.snapshots.find(params[:snapshot_id])
    diagram, validation = CableFusion::RestoreSnapshot.new(diagram:, snapshot:, actor: current_user).call

    render json: { data: CableFusion::PayloadBuilder.new(diagram:, validation:).call }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ { detail: "Snapshot not found" } ] }, status: :not_found
  end

  private

  def set_network_map
    map_id = params[:network_map_id] || params[:legacy_network_map_id]
    @network_map = scoped_network_maps.find(map_id)
  end

  def set_network_cable
    @network_cable = @network_map.network_cables.find(params[:network_cable_id])
  end

  def fusion_diagram_payload
    params.require(:fusion_diagram).permit(
      nodes: [ :id, :client_id, :type, :label, :x, :y, :rotation, metadata: {} ],
      ports: [ :id, :client_id, :node_id, :node_client_id, :name, :port_type, :capacity, :occupancy_limit, :position_x, :position_y, metadata: {} ],
      links: [ :id, :client_id, :source_port_id, :target_port_id, :source_port_client_id, :target_port_client_id, :link_kind, :fiber_side, :fiber_number, :status, metadata: {} ]
    ).to_h
  end
end
