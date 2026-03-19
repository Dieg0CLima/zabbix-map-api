class Api::V1::NetworkMapsV2Controller < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_network_map, only: %i[show update destroy health metrics events editor_state available_sites available_devices]

  def index
    render_data(data: current_organization.network_maps.order(:id).map { |map| Api::V1::NetworkMapSerializer.new(map).as_json })
  end

  def show
    render_data(data: Api::V1::NetworkMapSerializer.new(@network_map).as_json)
  end

  def create
    map = NetworkMaps::Create.new(organization: current_organization, payload: network_map_params).call
    render_data(data: Api::V1::NetworkMapSerializer.new(map).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    map = NetworkMaps::Update.new(network_map: @network_map, payload: network_map_params).call
    render_data(data: Api::V1::NetworkMapSerializer.new(map).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    NetworkMaps::Destroy.new(network_map: @network_map).call
    render_data(data: nil)
  end

  def editor_state
    render_data(data: NetworkMaps::FetchEditorState.new(network_map: @network_map, current_membership: current_membership).call)
  end

  def available_sites
    attached_ids = @network_map.map_nodes.where(mappable_type: "Site").select(:mappable_id)
    sites = current_organization.sites.where.not(id: attached_ids).order(:name)
    sites = sites.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: sites.limit(50).map { |site| { value: site.id, label: site.name, code: site.slug, meta: { slug: site.slug } } })
  end

  def available_devices
    attached_ids = @network_map.map_nodes.where(mappable_type: "Device").select(:mappable_id)
    devices = current_organization.devices.where.not(id: attached_ids).order(:name)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    devices = devices.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: devices.limit(50).map { |device| { value: device.id, label: device.name, code: device.hostname || device.id.to_s, meta: { site_id: device.site_id, role: device.role, status: device.status } } })
  end

  def health
    render_data(data: Monitoring::MapHealthFetcher.new(network_map: @network_map).call)
  end

  def metrics
    render_data(data: Zabbix::MetricsFetcher.new(network_map: @network_map).call)
  end

  def events
    render_data(data: Zabbix::ProblemFetcher.new(network_map: @network_map).call)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:id] || params[:map_id])
  end

  def network_map_params
    params.require(:network_map).permit(:name, :description, :source_type, :zabbix_connection_id, :active_base_layer, metadata: {})
  end
end
