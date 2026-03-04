class MapPops::Destroy
  def initialize(map_pop:)
    @map_pop = map_pop
  end

  def call
    @map_pop.destroy!
  end
end
