class Api::V1::NetworkProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_project, only: %i[show update destroy save]
  before_action :require_editor_or_admin!, only: %i[create update destroy save]

  def index
    projects = if admin_without_organization_context?
      NetworkMap.includes(:map_pops, :map_nodes, network_cables: :network_cable_points)
    else
      current_organization.network_maps.includes(:map_pops, :map_nodes, network_cables: :network_cable_points)
    end

    render json: { data: projects.map { |project| project_payload(project) } }, status: :ok
  end

  def show
    render json: { data: project_payload(@project) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    project = current_organization.network_maps.new(project_params)

    if project.save
      render json: { data: project_payload(project) }, status: :created
    else
      render json: { errors: project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      render json: { data: project_payload(@project) }, status: :ok
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def save
    project = NetworkMaps::PersistEditorState.new(network_map: @project, payload: editor_state_params).call
    render json: { data: project_payload(project) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @project.destroy
    head :no_content
  end

  private

  def set_project
    projects_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @project = projects_scope.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :source_type, :zabbix_mapid, :zabbix_connection_id, :active_base_layer)
  end

  def editor_state_params
    params.require(:editor_state).permit(
      :active_base_layer,
      :history_label,
      :history_index,
      draft_cable: {},
      pops: [ :id, :name, :lat, :lng, :color, { metadata: {} } ],
      markers: [ :id, :label, :node_kind, :lat, :lng, :icon, :color, :size, :zabbix_ref, :pop_id, { metadata: {} } ],
      edges: [ :id, :label, :cable_type, :status, :color, :weight, :pattern, :source_pop_id, :target_pop_id, :source_node_id, :target_node_id,
               { metadata: {} }, { points: [ :position, :lat, :lng ] } ]
    )
  end

  def project_payload(project)
    {
      id: project.id,
      organization_id: project.organization_id,
      name: project.name,
      description: project.description,
      active_base_layer: project.active_base_layer,
      pops: project.map_pops.order(:id).map do |pop|
        {
          id: pop.external_id,
          name: pop.name,
          lat: pop.lat,
          lng: pop.lng,
          color: pop.color,
          metadata: pop.metadata
        }
      end,
      nodes: project.map_nodes.order(:id).map do |node|
        {
          id: node.external_id,
          pop_id: node.map_pop&.external_id,
          label: node.label,
          node_kind: node.node_kind,
          lat: node.lat,
          lng: node.lng,
          icon: node.icon,
          color: node.color,
          size: node.size,
          metadata: node.metadata
        }
      end,
      cables: project.network_cables.order(:id).map do |cable|
        {
          id: cable.external_id,
          source_pop_id: cable.source_pop&.external_id,
          target_pop_id: cable.target_pop&.external_id,
          source_node_id: cable.source_node&.external_id,
          target_node_id: cable.target_node&.external_id,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          points: cable.network_cable_points.order(:position).map do |point|
            {
              position: point.position,
              lat: point.x,
              lng: point.y
            }
          end
        }
      end
    }
  end
end
