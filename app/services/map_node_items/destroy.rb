class MapNodeItems::Destroy
  def initialize(map_node_item:)
    @map_node_item = map_node_item
  end

  def call
    @map_node_item.destroy!
  end
end
