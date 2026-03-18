class Inventory::Sites::CreateService
  def initialize(organization:, params:)
    @organization = organization
    @params = params
  end

  def call
    site = @organization.sites.new(@params)
    site.save!
    site
  end
end
