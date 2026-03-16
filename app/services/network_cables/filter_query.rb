class NetworkCables::FilterQuery
  def initialize(scope:, params:, network_map:)
    @scope = scope
    @params = params
    @network_map = network_map
  end

  def call
    filter_by_status
    filter_by_cable_type
    filter_by_network_role
    filter_by_source_site
    filter_by_target_site
    filter_by_search_query
    filter_by_fiber_count_min
    filter_by_fiber_count_max

    @scope
  end

  private

  def filter_by_status
    return unless @params[:status].present?

    @scope = @scope.where(status: @params[:status])
  end

  def filter_by_cable_type
    return unless @params[:cable_type].present?

    @scope = @scope.where(cable_type: @params[:cable_type])
  end

  def filter_by_network_role
    return unless @params[:network_role].present?

    @scope = @scope.where("metadata ->> 'network_role' = ?", @params[:network_role])
  end

  def filter_by_source_site
    return unless @params[:source_site_id].present?

    @scope = @scope.where(source_site_id: resolve_site_id(@params[:source_site_id]))
  end

  def filter_by_target_site
    return unless @params[:target_site_id].present?

    @scope = @scope.where(target_site_id: resolve_site_id(@params[:target_site_id]))
  end

  def filter_by_search_query
    return unless @params[:q].present?

    query = "%#{@params[:q]}%"
    @scope = @scope.where("label ILIKE ? OR metadata ->> 'code' ILIKE ?", query, query)
  end

  def filter_by_fiber_count_min
    return unless @params[:fiber_count_min].present?

    @scope = @scope.where("(metadata ->> 'fiber_count')::int >= ?", @params[:fiber_count_min].to_i)
  end

  def filter_by_fiber_count_max
    return unless @params[:fiber_count_max].present?

    @scope = @scope.where("(metadata ->> 'fiber_count')::int <= ?", @params[:fiber_count_max].to_i)
  end

  def resolve_site_id(value)
    return value if value.to_s.match?(/\A\d+\z/)

    @network_map.sites.find_by(external_id: value)&.id
  end
end
