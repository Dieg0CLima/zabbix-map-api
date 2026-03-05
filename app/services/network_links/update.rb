class NetworkLinks::Update
  def initialize(network_link:, payload:)
    @network_link = network_link
    @payload = payload
  end

  def call
    @network_link.update!(@payload)
    @network_link
  end
end
