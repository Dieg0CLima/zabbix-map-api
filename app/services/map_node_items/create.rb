class MapNodeItems::Create
  def initialize(map_node:, payload:)
    @map_node = map_node
    @payload = payload
  end

  def call
    item = @map_node.map_node_items.new(@payload)
    item.save!
    item
  end
end
