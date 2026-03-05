module MapPops
  class PayloadBuilder
    def initialize(pop:)
      @pop = pop
    end

    def call
      {
        id: @pop.external_id || @pop.id,
        network_map_id: @pop.network_map_id,
        site_id: @pop.site&.external_id || @pop.site_id,
        site: site_payload,
        name: @pop.name,
        external_id: @pop.external_id,
        lat: @pop.lat,
        lng: @pop.lng,
        color: @pop.color,
        metadata: @pop.metadata,
        created_at: @pop.created_at,
        updated_at: @pop.updated_at
      }
    end

    private

    def site_payload
      return if @pop.site.blank?

      {
        external_id: @pop.site.external_id,
        name: @pop.site.name,
        status: @pop.site.status
      }
    end
  end
end
