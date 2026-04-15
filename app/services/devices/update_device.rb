class Devices::UpdateDevice
  def initialize(device:, params:, actor: nil)
    @device = device
    @params = params
    @actor = actor
  end

  def call
    ActiveRecord::Base.transaction do
      attrs = @params.deep_dup.except(:zabbix_connection_id, :zabbix_host_id)
      attrs[:metadata] = (@device.metadata || {}).merge(attrs[:metadata] || {}).merge("updated_by_id" => @actor&.id)
      @device.update!(attrs)
      Devices::ZabbixHostLinkUpserter.new(device: @device, organization: @device.organization, params: @params).call
      Devices::MonitoringProfileSync.new(device: @device).call
      @device.reload
    end
  end
end
