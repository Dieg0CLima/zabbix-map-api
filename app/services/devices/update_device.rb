class Devices::UpdateDevice
  attr_reader :removed_monitoring

  def initialize(device:, params:, actor: nil)
    @device = device
    @params = params
    @actor = actor
    @removed_monitoring = { items: 0, bindings: 0 }
  end

  def call
    ActiveRecord::Base.transaction do
      attrs = @params.deep_dup.except(:zabbix_connection_id, :zabbix_host_id)
      attrs[:metadata] = (@device.metadata || {}).merge(attrs[:metadata] || {}).merge("updated_by_id" => @actor&.id)
      @device.update!(attrs)
      @removed_monitoring = Devices::ZabbixHostLinkUpserter.new(device: @device, organization: @device.organization, params: @params).call
      Devices::MonitoringProfileSync.new(device: @device).call
      @device.reload
    end
  end
end
