class Api::V1::ZabbixLinksController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create destroy]
  before_action :set_linkable, only: %i[index create]
  before_action :set_zabbix_link, only: :destroy

  def index
    render_data(data: @linkable.zabbix_links.order(:id).map { |link| Api::V1::ZabbixLinkSerializer.new(link).as_json })
  end

  def create
    connection = find_record(current_organization.zabbix_connections, zabbix_link_params[:zabbix_connection_id])
    return if performed?

    zabbix_link = Zabbix::Links::BindResourceService.new(linkable: @linkable, connection:, params: zabbix_link_params.except(:zabbix_connection_id)).call
    render_data(data: Api::V1::ZabbixLinkSerializer.new(zabbix_link).as_json, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    Zabbix::Links::UnbindResourceService.new(zabbix_link: @zabbix_link).call
    render_data(data: nil)
  end

  private

  def set_linkable
    @linkable = if params[:device_id]
      find_record(current_organization.devices, params[:device_id])
    elsif params[:interface_id]
      iface = find_record(DeviceInterface.joins(:device).where(devices: { organization_id: current_organization.id }), params[:interface_id])
      iface
    end
  end

  def set_zabbix_link
    @zabbix_link = find_record(current_organization.zabbix_links, params[:id])
  end

  def zabbix_link_params
    params.require(:zabbix_link).permit(:zabbix_connection_id, :resource_type, :external_id, :external_key, :name, metadata: {})
  end
end
