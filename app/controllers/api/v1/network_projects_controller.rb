class Api::V1::NetworkProjectsController < ApplicationController
  include EditorStateParams
  include OrganizationScoped
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_project, only: %i[show update destroy save]
  before_action :require_editor_or_admin!, only: %i[create update destroy save]

  def index
    projects = scoped_network_maps.includes(:sites, :map_nodes, network_cables: :network_cable_points)

    render json: { data: projects.map { |project| project_payload(project) } }, status: :ok
  end

  def show
    render json: { data: project_payload(@project) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    project = NetworkProjects::Create.new(
      organization: current_organization,
      payload: permitted_project_payload.to_h
    ).call

    render json: { data: project_payload(project) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    NetworkProjects::Update.new(
      project: @project,
      payload: permitted_project_payload.to_h
    ).call

    render json: { data: project_payload(@project) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def save
    project = NetworkMaps::PersistEditorState.new(network_map: @project, payload: editor_state_params).call
    render json: { data: project_payload(project) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    NetworkProjects::Destroy.new(project: @project).call
    head :no_content
  end

  private

  def set_project
    @project = scoped_network_maps.find(params[:id])
  end

  def permitted_project_payload
    params.require(:project).permit(:name, :description, :source_type, :zabbix_mapid, :zabbix_connection_id, :active_base_layer)
  end

  def project_payload(project)
    NetworkProjects::PayloadBuilder.new(project:).call
  end
end
