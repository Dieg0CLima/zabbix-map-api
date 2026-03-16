class Api::V1::SitesController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_site, only: %i[show update destroy]

  def index
    sites = scoped_sites.order(:name)
    render json: { data: sites.map { |s| site_payload(s) } }, status: :ok
  end

  def show
    render json: { data: site_payload(@site) }, status: :ok
  end

  def create
    site = scoped_sites.create!(permitted_site_payload)
    render json: { data: site_payload(site) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    @site.update!(permitted_site_payload)
    render json: { data: site_payload(@site) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    @site.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o site")
  end

  private

  def set_site
    @site = scoped_sites.find(params[:id])
  end

  def permitted_site_payload
    params.require(:site).permit(:name, :external_id, :address, :lat, :lng, :status, metadata: {})
  end

  def site_payload(site)
    {
      id: site.id,
      organization_id: site.organization_id,
      external_id: site.external_id,
      name: site.name,
      address: site.address,
      lat: site.lat,
      lng: site.lng,
      status: site.status,
      metadata: site.metadata,
      created_at: site.created_at,
      updated_at: site.updated_at
    }
  end
end
