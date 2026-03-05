class Api::V1::SitesController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_site, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: scoped_sites.order(:id).map { |site| site_payload(site) } }, status: :ok
  end

  def show
    render json: { data: site_payload(@site) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    site = Sites::Create.new(organization: current_organization, payload: permitted_site_payload.to_h).call
    render json: { data: site_payload(site) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    site = Sites::Update.new(site: @site, payload: permitted_site_payload.to_h).call
    render json: { data: site_payload(site) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    Sites::Destroy.new(site: @site).call
    head :no_content
  end

  private

  def set_site
    @site = scoped_sites.find(params[:id])
  end

  def scoped_sites
    admin_without_organization_context? ? Site : current_organization.sites
  end

  def permitted_site_payload
    params.require(:site).permit(:external_id, :name, :address, :lat, :lng, :status, metadata: {})
  end

  def site_payload(site)
    Sites::PayloadBuilder.new(site:).call
  end
end
