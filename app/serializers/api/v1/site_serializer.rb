class Api::V1::SiteSerializer
  def initialize(site)
    @site = site
  end

  def as_json(*)
    {
      id: @site.id,
      name: @site.name,
      slug: @site.slug,
      description: @site.description,
      address: @site.address,
      city: @site.city,
      state: @site.state,
      lat: @site.lat,
      lng: @site.lng,
      metadata: @site.metadata,
      created_at: @site.created_at,
      updated_at: @site.updated_at
    }
  end
end
