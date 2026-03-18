module Sites
  class PayloadBuilder
    def initialize(site:)
      @site = site
    end

    def call
      {
        id:              @site.id,
        organization_id: @site.organization_id,
        external_id:     @site.external_id,
        name:            @site.name,
        address:         @site.address,
        lat:             @site.lat,
        lng:             @site.lng,
        status:          @site.status,
        metadata:        @site.metadata,
        created_at:      @site.created_at,
        updated_at:      @site.updated_at
      }
    end
  end
end
