module MapElements
  class Update
    VISUAL_ATTRS = %i[
      lat lng icon_override color_override label_override
      size_override collapsed display_order metadata
    ].freeze

    def initialize(map_element:, payload:)
      @map_element = map_element
      @payload = payload
    end

    def call
      @map_element.update!(@payload.slice(*VISUAL_ATTRS))
      @map_element
    end
  end
end
