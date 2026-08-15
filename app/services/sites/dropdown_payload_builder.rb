class Sites::DropdownPayloadBuilder
  def initialize(site)
    @site = site
  end

  def call
    {
      value: @site.id,
      label: @site.name,
      code: @site.slug,
      meta: {
        slug: @site.slug
      }
    }
  end
end
