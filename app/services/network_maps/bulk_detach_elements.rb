class NetworkMaps::BulkDetachElements
  def initialize(network_map:, ids:)
    @network_map = network_map
    @ids = ids
  end

  def call
    successes = []
    errors = []

    ActiveRecord::Base.transaction do
      @ids.each do |id|
        node = @network_map.map_nodes.find(id)
        node.destroy!
        successes << { id: }
      rescue StandardError => e
        errors << { id:, detail: e.message }
      end
    end

    { successes:, errors: }
  end
end
