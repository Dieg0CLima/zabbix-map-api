class NetworkLinks::Create
  def initialize(organization:, payload:)
    @organization = organization
    @payload = payload
  end

  def call
    link = @organization.network_links.new(@payload)
    link.save!
    link
  end
end
