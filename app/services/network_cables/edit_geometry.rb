class NetworkCables::EditGeometry
  MIN_POINTS = 2

  def initialize(cable:, network_map:, payload:, actor_email:)
    @cable = cable
    @payload = payload.with_indifferent_access
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    previous_state = NetworkCables::EventStateBuilder.call(cable: @cable)
    @endpoint_binding_updates = {}

    ActiveRecord::Base.transaction do
      ensure_geometry_version!

      points = current_points
      updated_points = apply_operation(points)
      validate_points!(updated_points)

      replace_points!(updated_points)
      apply_endpoint_binding_updates!
      bump_geometry_version!
      @cable.reload

      current_state = NetworkCables::EventStateBuilder.call(cable: @cable)
      @event_recorder.record!(
        cable: @cable,
        event_type: NetworkCables::EventTypeInferer.infer(
          previous_state: previous_state,
          current_state: current_state,
          points_changed: previous_state[:points] != current_state[:points]
        ),
        before_state: previous_state,
        after_state: current_state,
        notes: "Geometria do cabo atualizada"
      )
    end

    @cable.reload
  end

  private

  def current_points
    @cable.network_cable_points.order(:position).map do |point|
      {
        position: point.position,
        x: point.x,
        y: point.y
      }
    end
  end

  def apply_operation(points)
    operation = @payload[:operation].to_s

    case operation
    when "replace_all"
      replace_all(points)
    when "move_point"
      move_point(points)
    when "insert_point"
      insert_point(points)
    when "remove_point"
      remove_point(points)
    when "remove_segment"
      remove_segment(points)
    when "attach_endpoint_to_pop"
      attach_endpoint_to_pop(points)
    when "attach_endpoint_to_site"
      attach_endpoint_to_site(points)
    when "attach_endpoint_to_node"
      attach_endpoint_to_node(points)
    else
      raise NetworkCables::Errors::InvalidGeometryOperation.new(
        operation: operation,
        details: { reason: "unsupported_operation" }
      )
    end
  end

  def replace_all(_points)
    raw_points = @payload[:points]
    NetworkCables::PointSetValidator.validate!(raw_points)
    normalize_positions(NetworkCables::PointNormalizer.normalize(raw_points))
  end

  def move_point(points)
    position = integer_param!(:position)
    moved_point = @payload[:point] || {}
    normalized = NetworkCables::PointNormalizer.normalize([ moved_point ]).first

    updated = points.map(&:dup)
    point = updated.find { |p| p[:position] == position }
    raise_invalid_operation!("point_not_found", position: position) unless point

    point[:x] = normalized[:x]
    point[:y] = normalized[:y]

    normalize_positions(updated)
  end

  def insert_point(points)
    after_position = integer_param!(:after_position)
    raw_points = Array(@payload[:points])
    raise_invalid_operation!("points_blank") if raw_points.empty?

    normalized_new = NetworkCables::PointNormalizer.normalize(raw_points)
    updated = points.map(&:dup)
    insertion_index = updated.index { |p| p[:position] == after_position }
    raise_invalid_operation!("point_not_found", after_position: after_position) unless insertion_index

    updated.insert(insertion_index + 1, *normalized_new.map { |p| p.slice(:x, :y) })
    normalize_positions(updated)
  end

  def remove_point(points)
    position = integer_param!(:position)
    updated = points.reject { |p| p[:position] == position }.map(&:dup)
    raise_invalid_operation!("point_not_found", position: position) if updated.size == points.size

    normalize_positions(updated)
  end

  def remove_segment(points)
    from_position = integer_param!(:from_position)
    to_position = integer_param!(:to_position)
    if from_position > to_position
      raise_invalid_operation!("invalid_range", from_position: from_position, to_position: to_position)
    end

    updated = points.reject { |p| p[:position].between?(from_position, to_position) }.map(&:dup)
    if updated.size == points.size
      raise_invalid_operation!("segment_not_found", from_position: from_position, to_position: to_position)
    end

    normalize_positions(updated)
  end

  def attach_endpoint_to_pop(points)
    side = @payload[:side].to_s
    unless %w[source target].include?(side)
      raise_invalid_operation!("invalid_side", side: side)
    end

    pop_id = @payload[:pop_id]
    pop = resolve_pop(pop_id)
    raise_invalid_operation!("pop_not_found", pop_id: pop_id) if pop.nil?

    updated = points.map(&:dup)
    endpoint_point = side == "source" ? updated.first : updated.last
    endpoint_point[:x] = pop.lat
    endpoint_point[:y] = pop.lng

    register_endpoint_binding(side: side, pop: pop)
    normalize_positions(updated)
  end

  def attach_endpoint_to_node(points)
    side = @payload[:side].to_s
    unless %w[source target].include?(side)
      raise_invalid_operation!("invalid_side", side: side)
    end

    node_id = @payload[:node_id]
    node = resolve_node(node_id)
    raise_invalid_operation!("node_not_found", node_id: node_id) if node.nil?

    updated = points.map(&:dup)
    endpoint_point = side == "source" ? updated.first : updated.last
    endpoint_point[:x] = node.lat
    endpoint_point[:y] = node.lng

    register_node_endpoint_binding(side: side, node: node)
    normalize_positions(updated)
  end

  def attach_endpoint_to_site(points)
    side = @payload[:side].to_s
    unless %w[source target].include?(side)
      raise_invalid_operation!("invalid_side", side: side)
    end

    site_id = @payload[:site_id]
    site = resolve_site(site_id)
    raise_invalid_operation!("site_not_found", site_id: site_id) if site.nil?

    node = resolve_site_node(site.id)
    raise_invalid_operation!("site_node_not_found", site_id: site.id) if node.nil?

    updated = points.map(&:dup)
    endpoint_point = side == "source" ? updated.first : updated.last
    endpoint_point[:x] = node.lat
    endpoint_point[:y] = node.lng

    register_site_endpoint_binding(side: side, site: site)
    normalize_positions(updated)
  end

  def validate_points!(points)
    NetworkCables::PointSetValidator.validate!(points)
  end

  def replace_points!(points)
    @cable.network_cable_points.destroy_all
    points.each { |point| @cable.network_cable_points.create!(point.slice(:position, :x, :y)) }
  end

  def apply_endpoint_binding_updates!
    return if @endpoint_binding_updates.blank?

    @cable.assign_attributes(@endpoint_binding_updates)
    @cable.save!
  end

  def normalize_positions(points)
    Array(points).map.with_index do |point, index|
      {
        position: index,
        x: point[:x],
        y: point[:y]
      }
    end
  end

  def ensure_geometry_version!
    expected = @payload[:geometry_version]
    return if expected.nil?

    expected_version = Integer(expected)
    current_version = geometry_version

    return if expected_version == current_version

    raise NetworkCables::Errors::GeometryConflict.new(
      expected_version: expected_version,
      current_version: current_version
    )
  rescue ArgumentError, TypeError
    raise_invalid_operation!("invalid_geometry_version", geometry_version: expected)
  end

  def bump_geometry_version!
    metadata = (@cable.metadata.presence || {}).dup
    metadata["geometry_version"] = geometry_version + 1
    @cable.update!(metadata: metadata)
  end

  def geometry_version
    @cable.metadata&.[]("geometry_version").to_i
  end

  def integer_param!(name)
    Integer(@payload[name])
  rescue ArgumentError, TypeError
    raise_invalid_operation!("invalid_integer_param", param: name)
  end

  def raise_invalid_operation!(reason, extra = {})
    raise NetworkCables::Errors::InvalidGeometryOperation.new(
      operation: @payload[:operation].to_s,
      details: extra.merge(reason: reason)
    )
  end

  def resolve_pop(value)
    return nil if value.blank?

    scope = @cable.network_map.map_pops
    string_value = value.to_s
    return scope.find_by(id: string_value.to_i) if string_value.match?(/\A\d+\z/)

    scope.find_by(external_id: string_value)
  end

  def resolve_node(value)
    return nil if value.blank?

    scope = @cable.network_map.map_nodes
    string_value = value.to_s
    return scope.find_by(id: string_value.to_i) if string_value.match?(/\A\d+\z/)

    scope.find_by(external_id: string_value)
  end

  def resolve_site(value)
    return nil if value.blank?

    scope = @cable.network_map.organization.sites
    string_value = value.to_s
    return scope.find_by(id: string_value.to_i) if string_value.match?(/\A\d+\z/)

    nil
  end

  def resolve_site_node(site_id)
    @cable.network_map.map_nodes.find_by(mappable_type: "Site", mappable_id: site_id)
  end

  def register_node_endpoint_binding(side:, node:)
    updates =
      if side == "source"
        {
          source_node_id: node.id,
          source_pop_id: nil,
          source_site_id: nil,
          source_element_id: nil
        }
      else
        {
          target_node_id: node.id,
          target_pop_id: nil,
          target_site_id: nil,
          target_element_id: nil
        }
      end

    @endpoint_binding_updates.merge!(updates)
  end

  def register_endpoint_binding(side:, pop:)
    updates =
      if side == "source"
        {
          source_pop_id: pop.external_id,
          source_node_id: nil,
          source_site_id: nil,
          source_element_id: nil
        }
      else
        {
          target_pop_id: pop.external_id,
          target_node_id: nil,
          target_site_id: nil,
          target_element_id: nil
        }
      end

    @endpoint_binding_updates.merge!(updates)
  end

  def register_site_endpoint_binding(side:, site:)
    updates =
      if side == "source"
        {
          source_site_id: site.id,
          source_pop_id: nil,
          source_node_id: nil,
          source_element_id: nil
        }
      else
        {
          target_site_id: site.id,
          target_pop_id: nil,
          target_node_id: nil,
          target_element_id: nil
        }
      end

    @endpoint_binding_updates.merge!(updates)
  end
end
