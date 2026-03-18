class Api::V1::SitesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_site, only: %i[show update destroy]

  def index
    sites = current_organization.sites.order(:id)
    sites = sites.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: sites.map { |site| Api::V1::SiteSerializer.new(site).as_json })
  end

  def dropdown
    sites = current_organization.sites.order(:name)
    sites = sites.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: sites.limit(50).map { |site| { value: site.id, label: site.name, code: site.slug, meta: { slug: site.slug } } })
  end

  def show
    render_data(data: Api::V1::SiteSerializer.new(@site).as_json)
  end

  def create
    site, marker = Sites::CreateSite.new(organization: current_organization, params: site_params.to_h.deep_symbolize_keys, map_context: map_context_params.to_h.deep_symbolize_keys, actor: current_user).call
    render_data(data: { site: Api::V1::SiteSerializer.new(site).as_json, marker: marker && Api::V1::MapElementSerializer.new(marker).as_json }, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    site = Sites::UpdateSite.new(site: @site, params: site_params.to_h.deep_symbolize_keys, actor: current_user).call
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
    raw = params.require(:site)
    raw[:metadata] = {} if raw.key?(:metadata) && raw[:metadata].nil?
    raw.permit(:name, :slug, :description, :address, :city, :state, :lat, :lng, metadata: {})
  end

  def map_context_params
    raw = params.fetch(:map_context, ActionController::Parameters.new)
    raw[:metadata] = {} if raw.key?(:metadata) && raw[:metadata].nil?
    raw.permit(:add_to_map, :network_map_id, :label_override, :color_override, :icon_override, metadata: {}, position: %i[lat lng x y])
  end
end
