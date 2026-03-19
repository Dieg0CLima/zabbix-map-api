class Inventory::Sites::UpdateService
  def initialize(site:, params:)
    @site = site
    @params = params
  end

  def call
    @site.update!(@params)
    @site
  end
end
