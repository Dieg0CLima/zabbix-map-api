class Api::V1::NetworkLinksController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_link, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: scoped_network_links.order(:id).map { |link| network_link_payload(link) } }, status: :ok
  end

  def show
    render json: { data: network_link_payload(@network_link) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    link = NetworkLinks::Create.new(organization: current_organization, payload: permitted_network_link_payload.to_h).call
    render json: { data: network_link_payload(link) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    link = NetworkLinks::Update.new(network_link: @network_link, payload: permitted_network_link_payload.to_h).call
    render json: { data: network_link_payload(link) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    NetworkLinks::Destroy.new(network_link: @network_link).call
    head :no_content
  end

  private

  def set_network_link
    @network_link = scoped_network_links.find(params[:id])
  end

  def scoped_network_links
    admin_without_organization_context? ? NetworkLink : current_organization.network_links
  end

  def permitted_network_link_payload
    params.require(:network_link).permit(
      :external_id,
      :label,
      :source_device_id,
      :target_device_id,
      :source_site_id,
      :target_site_id,
      :link_type,
      :bandwidth_mbps,
      :status,
      :zabbix_item_ref,
      metadata: {}
    )
  end

  def network_link_payload(network_link)
    NetworkLinks::PayloadBuilder.new(network_link:).call
  end
end
