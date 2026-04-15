class NetworkCables::EditGeometry
  MIN_POINTS = 2

  def initialize(cable:, network_map:, payload:, actor_email:)
    @cable = cable
    @payload = payload.with_indifferent_access
    @event_recorder = NetworkCables::EventRecorder.new(network_map:, actor_email:)
  end

  def call
    previous_state = NetworkCables::EventStateBuilder.call(cable: @cable)

    ActiveRecord::Base.transaction do
      ensure_geometry_version!

      points = current_points
      updated_points = apply_operation(points)
      validate_points!(updated_points)

      replace_points!(updated_points)
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

  def validate_points!(points)
    NetworkCables::PointSetValidator.validate!(points)
  end

  def replace_points!(points)
    @cable.network_cable_points.destroy_all
    points.each { |point| @cable.network_cable_points.create!(point.slice(:position, :x, :y)) }
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
end
