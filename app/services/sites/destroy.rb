class Sites::Destroy
  def initialize(site:)
    @site = site
  end

  def call
    @site.destroy!
  end
end
