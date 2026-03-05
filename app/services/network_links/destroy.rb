class NetworkLinks::Destroy
  def initialize(network_link:)
    @network_link = network_link
  end

  def call
    @network_link.destroy!
  end
end
