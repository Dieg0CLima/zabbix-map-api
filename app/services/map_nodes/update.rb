class MapNodes::Update
  def initialize(map_node:, payload:)
    @map_node = map_node
    @payload = payload
  end

  def call
    @map_node.update!(@payload)
    @map_node
  end
end
