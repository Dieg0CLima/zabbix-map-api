class Sites::Update
  def initialize(site:, payload:)
    @site = site
    @payload = payload
  end

  def call
    @site.update!(@payload)
    @site
  end
end
