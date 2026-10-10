# Removes a device and everything local that hangs from it, in a single transaction.
# Never talks to Zabbix: only local links (zabbix_links) are removed.
class Devices::DestroyDevice
  class ConfirmationRequired < StandardError
    attr_reader :impact

    def initialize(impact)
      @impact = impact
      super("Device removal needs confirmation")
    end
  end

  def initialize(device:)
    @device = device
  end

  # Returns the impact that was removed. Raises ConfirmationRequired when there is
  # anything to cascade and the caller did not confirm.
  def call(confirm: false)
    ActiveRecord::Base.transaction do
      @device.lock!
      impact = Devices::RemovalImpact.new(device: @device).call
      raise ConfirmationRequired, impact if impact[:has_dependencies] && !confirm

      destroy_map_nodes
      ZabbixLink.where(linkable_type: "DeviceInterface", linkable_id: @device.device_interfaces.select(:id)).destroy_all
      ZabbixLink.where(linkable: @device).destroy_all
      NetworkLink.for_device(@device.id).delete_all
      @device.reload.destroy!
      impact
    end
  end

  private

  # MapNode destroys its items, bindings and edges and nullifies the cable endpoints.
  def destroy_map_nodes
    MapNode.where(mappable: @device).find_each(&:destroy!)
  end
end
