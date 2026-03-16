module Sites
  class PayloadBuilder
    def initialize(site:)
      @site = site
    end

    def call
      {
        id: @site.external_id || @site.id,
        network_map_id: @site.network_map_id,
        name: @site.name,
        external_id: @site.external_id,
        lat: @site.lat,
        lng: @site.lng,
        color: @site.color,
        address: @site.address,
        status: @site.status,
        metadata: @site.metadata,
        created_at: @site.created_at,
        updated_at: @site.updated_at
      }
    end
  end
end
