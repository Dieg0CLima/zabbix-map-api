class Api::V1::SitesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_site, only: %i[show update destroy]

  def index
    sites = current_organization.sites.order(:id)
    render_data(data: sites.map { |site| Api::V1::SiteSerializer.new(site).as_json })
  end

  def show
    render_data(data: Api::V1::SiteSerializer.new(@site).as_json)
  end

  def create
    site = Inventory::Sites::CreateService.new(organization: current_organization, params: site_params).call
    render_data(data: Api::V1::SiteSerializer.new(site).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    site = Inventory::Sites::UpdateService.new(site: @site, params: site_params).call
    render_data(data: Api::V1::SiteSerializer.new(site).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @site.destroy!
    render_data(data: nil, status: :ok)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_record_errors(@site)
  end

  private

  def set_site
    @site = find_record(current_organization.sites, params[:id])
  end

  def site_params
    params.require(:site).permit(:name, :slug, :description, :address, :city, :state, :lat, :lng, metadata: {})
  end
end
