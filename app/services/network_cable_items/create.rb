class NetworkCableItems::Create
  def initialize(network_cable:, payload:)
    @network_cable = network_cable
    @payload = payload
  end

  def call
    item = @network_cable.network_cable_items.new(@payload)
    item.save!
    item
  end
end
