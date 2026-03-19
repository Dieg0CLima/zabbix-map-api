class NetworkMaps::BulkAttachSites
  def initialize(network_map:, items:, actor: nil)
    @network_map = network_map
    @items = items
    @actor = actor
  end

  def call
    process_items do |item|
      site = @network_map.organization.sites.find(item[:site_id])
      Sites::AttachSiteToMap.new(network_map: @network_map, site:, params: marker_params(item), actor: @actor).call
    end
  end

  private

  def process_items
    successes = []
    errors = []
    ActiveRecord::Base.transaction do
      @items.each do |item|
        successes << Api::V1::MapElementSerializer.new(yield(item)).as_json
      rescue StandardError => e
        errors << { item:, detail: e.message }
      end
    end
    { successes:, errors: }
  end

  def marker_params(item)
    position = item[:position] || {}
    {
      x: position[:lng] || position[:x], y: position[:lat] || position[:y], lat: position[:lat] || position[:y], lng: position[:lng] || position[:x],
      label_override: item[:label_override], color: item[:color_override], icon: item[:icon_override], metadata: item[:metadata] || {}
    }
  end
end
