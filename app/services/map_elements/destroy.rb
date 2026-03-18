module MapElements
  class Destroy
    def initialize(map_element:)
      @map_element = map_element
    end

    def call
      @map_element.destroy!
    end
  end
end
