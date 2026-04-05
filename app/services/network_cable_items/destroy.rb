class NetworkCableItems::Destroy
  def initialize(network_cable_item:)
    @network_cable_item = network_cable_item
  end

  def call
    @network_cable_item.destroy!
  end
end
