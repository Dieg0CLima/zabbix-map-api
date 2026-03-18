class Inventory::MapNodes::UpdateLayoutService
  def initialize(map_node:, params:)
    @map_node = map_node
    @params = params
  end

  def call
    @map_node.update!(@params)
    @map_node
  end
end
