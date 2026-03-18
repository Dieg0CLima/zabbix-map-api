module MapElementItems
  class Destroy
    def initialize(map_element_item:)
      @map_element_item = map_element_item
    end

    def call
      @map_element_item.destroy!
    end
  end
end
