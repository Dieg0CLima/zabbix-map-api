class Zabbix::Links::BindResourceService
  def initialize(linkable:, connection:, params:)
    @linkable = linkable
    @connection = connection
    @params = params
  end

  def call
    zabbix_link = ZabbixLink.new(
      organization_id: organization_id,
      zabbix_connection: @connection,
      linkable: @linkable,
      resource_type: @params[:resource_type],
      external_id: @params[:external_id],
      external_key: @params[:external_key],
      name: @params[:name],
      metadata: @params[:metadata] || {}
    )
    zabbix_link.save!
    zabbix_link
  end

  private

  def organization_id
    @linkable.respond_to?(:organization_id) ? @linkable.organization_id : @linkable.device.organization_id
  end
end
