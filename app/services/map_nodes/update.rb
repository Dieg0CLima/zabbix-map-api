class MapNodes::Update
  def initialize(map_node:, payload:)
    @map_node = map_node
    @payload = payload
  end

  def call
    @map_node.update!(linked_payload)
    @map_node
  end

  private

  def linked_payload
    @linked_payload ||= MapNodes::ZabbixHostLinker.new(network_map: @map_node.network_map, payload: @payload).call
  end
end
