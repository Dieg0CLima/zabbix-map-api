class Api::V1::MapMonitoringBindingsController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy]
  before_action :set_network_map
  before_action :set_map_node
  before_action :set_binding, only: %i[update destroy]

  def index
    render_data(data: @map_node.monitoring_bindings.order(:id).map { |binding| Api::V1::MapMonitoringBindingSerializer.new(binding).as_json })
  end

  def create
    binding = Monitoring::MapBindings::CreateService.new(map_node: @map_node, params: map_monitoring_binding_params).call
    render_data(data: Api::V1::MapMonitoringBindingSerializer.new(binding).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    binding = Monitoring::MapBindings::UpdateService.new(binding: @binding, params: map_monitoring_binding_params).call
    render_data(data: Api::V1::MapMonitoringBindingSerializer.new(binding).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @binding.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed
    render_record_errors(@binding)
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:map_id] || params[:network_map_id])
  end

  def set_map_node
    @map_node = find_record(@network_map.map_nodes, params[:node_id])
  end

  def set_binding
    @binding = find_record(@map_node.monitoring_bindings, params[:id])
  end

  def map_monitoring_binding_params
    params.require(:map_monitoring_binding).permit(:zabbix_link_id, :metric_type, :display_mode, :label, :severity_source, metadata: {})
  end
end
