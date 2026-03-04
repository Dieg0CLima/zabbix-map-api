class MapPops::Update
  def initialize(map_pop:, payload:)
    @map_pop = map_pop
    @payload = payload
  end

  def call
    @map_pop.update!(@payload)
    @map_pop
  end
end
