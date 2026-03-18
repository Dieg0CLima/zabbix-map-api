class Api::V1::SitesController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_site, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    sites = scoped_sites.order(:name)
    render json: { data: sites.map { |s| site_payload(s) } }, status: :ok
  end

  def show
    render json: { data: site_payload(@site) }, status: :ok
  end

  def create
    site = Sites::Create.new(
      organization: current_organization,
      payload:      permitted_site_params.to_h
    ).call

    render json: { data: site_payload(site) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    Sites::Update.new(site: @site, payload: permitted_site_params.to_h).call

    render json: { data: site_payload(@site) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    Sites::Destroy.new(site: @site).call

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o Site")
  end

  private

  def set_site
    @site = scoped_sites.find_by!(external_id: params[:id])
  rescue ActiveRecord::RecordNotFound
    @site = scoped_sites.find(params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @site.blank?
  end

  def scoped_sites
    current_organization.sites
  end

  def permitted_site_params
    params.require(:site).permit(:external_id, :name, :address, :lat, :lng, :status, metadata: {})
  end

  def site_payload(site)
    Sites::PayloadBuilder.new(site:).call
  end
end
