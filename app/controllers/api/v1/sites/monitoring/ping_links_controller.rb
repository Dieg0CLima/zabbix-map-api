class Api::V1::Sites::Monitoring::PingLinksController < Api::V1::BaseController
  before_action :set_network_map
  before_action :set_site
  before_action :require_editor_or_admin!, only: %i[create destroy]

  def show
    payload = Sites::Monitoring::PingLinkCatalog.new(
      network_map: @network_map,
      site: @site
    ).call
    render_data(data: payload)
  end

  def create
    result = Sites::Monitoring::PingLinkUpserter.new(
      network_map: @network_map,
      site: @site,
      device_id: create_params[:device_id],
      zabbix_item_id: create_params[:zabbix_item_id],
      alias_name: create_params[:alias]
    ).call

    render_data(
      data: {
        linked_item: MapNodeItems::PayloadBuilder.new(map_node_item: result[:map_node_item]).call,
        replaced_count: result[:replaced_count],
        device: {
          id: result[:device].id,
          name: result[:device].name
        }
      }
    )
  rescue Sites::Monitoring::ValidationError => e
    render_errors(status: e.status, errors: [ { source: e.source, detail: e.message } ])
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    removed_count = Sites::Monitoring::PingLinkRemover.new(
      network_map: @network_map,
      site: @site
    ).call

    render_data(data: { removed_count: removed_count })
  end

  private

  def set_network_map
    @network_map = find_record(current_organization.network_maps, params[:network_map_id])
  end

  def set_site
    return if performed?

    @site = find_record(current_organization.sites, params[:site_id])
  end

  def create_params
    params.require(:monitoring_ping_link).permit(:device_id, :zabbix_item_id, :alias)
  end
end
