class Api::V1::NetworkMapsV2Controller < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_network_map, only: %i[show update destroy health metrics events]

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
