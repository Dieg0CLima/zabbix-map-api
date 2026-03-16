module MapPops
  class PayloadBuilder
    def initialize(pop:)
      @pop = pop
    end

    def call
      {
        id: @pop.external_id || @pop.id,
        network_map_id: @pop.network_map_id,
        name: @pop.name,
        external_id: @pop.external_id,
        lat: @pop.lat,
        lng: @pop.lng,
        color: @pop.color,
        site_id: @pop.site_id,
        metadata: @pop.metadata,
        created_at: @pop.created_at,
        updated_at: @pop.updated_at
      }
    end
  end
end
