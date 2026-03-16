class Sites::Create
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
  end

  def call
    site = @network_map.sites.new(@payload)
    site.save!
    site
  end
end
