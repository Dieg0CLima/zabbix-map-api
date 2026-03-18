module MapElementItems
  class Create
    def initialize(map_element:, payload:)
      @map_element = map_element
      @payload = payload
    end

    def call
      item = @map_element.map_element_items.new(@payload)
      item.save!
      item
    end
  end
end
