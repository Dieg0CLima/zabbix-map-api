module CableFusion
  class LoadDiagram
    def initialize(cable:)
      @cable = cable
    end

    def call
      CableFusion::Diagram
        .includes(nodes: :ports, links: [])
        .find_or_create_by!(network_cable: @cable) do |diagram|
          diagram.status = "draft"
          diagram.version = 0
        end
    end
  end
end
