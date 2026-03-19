class Sites::DetachSiteFromMap
  def initialize(map_node:)
    @map_node = map_node
  end

  def call
    @map_node.destroy!
  end
end
