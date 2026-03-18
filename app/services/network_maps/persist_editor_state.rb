class NetworkMaps::PersistEditorState
  # Applies a full editor snapshot using incremental upserts.
  #
  # Key guarantees:
  # - no destroy_all (preserves control over FK order)
  # - stable internal IDs matched by external_id
  # - stale records removed in FK-safe order (cables → elements)
  # - all operations in a single transaction with row lock on network_map
  #
  # Payload format expected:
  #   {
  #     active_base_layer: "standard"|"terrain"|"dark",
  #     history_label: "...",
  #     history_index: 0,
  #     draft_cable: {...} | null,
  #     elements: [ { id: external_id, mappable_type: "Site"|"Device", mappable_id: int,
  #                   lat:, lng:, label_override:, icon_override:, color_override:,
  #                   size_override:, collapsed:, display_order:, metadata: } ],
  #     edges: [ { id: external_id, source_element_id: ext_id, target_element_id: ext_id,
  #                label:, cable_type:, status:, color:, weight:, pattern:, metadata:,
  #                points: [{position:, lat:, lng:}] } ]
  #   }
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload

    @element_by_external_id = {}
    @sanitized_elements = []
    @sanitized_cables = []
  end

  def call
    ActiveRecord::Base.transaction do
      @network_map.lock!

      validate_payload_uniqueness!
      update_map!
      upsert_elements!
      upsert_cables!
      cleanup_stale_records!
      create_snapshot!
    end

    @network_map.reload
  end

  private

  def update_map!
    @network_map.update!(
      active_base_layer: @payload[:active_base_layer] || @network_map.active_base_layer
    )
  end

  def upsert_elements!
    existing = @network_map.map_elements.index_by(&:external_id)
    payload_external_ids = []

    elements_payload.each do |elem|
      external_id = elem[:id].to_s
      payload_external_ids << external_id

      record = existing[external_id] || @network_map.map_elements.new(
        external_id:    external_id,
        mappable_type:  elem[:mappable_type],
        mappable_id:    elem[:mappable_id]
      )

      record.assign_attributes(build_element_attrs(elem))
      record.save!

      @element_by_external_id[external_id] = record
      @sanitized_elements << sanitized_element_payload(record)
    end

    @stale_element_external_ids = existing.keys - payload_external_ids
  end

  def upsert_cables!
    existing = @network_map.network_cables.includes(:network_cable_points).index_by(&:external_id)
    payload_external_ids = []

    cables_payload.each do |cable|
      external_id = cable[:id].to_s
      payload_external_ids << external_id

      source_element = resolve_element!(cable[:source_element_id], field: :source_element_id)
      target_element = resolve_element!(cable[:target_element_id], field: :target_element_id)
      points = sanitize_points!(cable[:points])

      record = existing[external_id] || @network_map.network_cables.new(external_id:)
      record.assign_attributes(
        label:          cable[:label],
        cable_type:     cable[:cable_type] || "manual",
        status:         cable[:status] || "planned",
        color:          cable[:color],
        weight:         cable[:weight],
        pattern:        cable[:pattern],
        source_element: source_element,
        target_element: target_element,
        metadata:       sanitize_metadata(cable[:metadata])
      )
      record.save!

      replace_points!(record, points)
      @sanitized_cables << sanitized_cable_payload(record, points)
    end

    @stale_cable_external_ids = existing.keys - payload_external_ids
  end

  def cleanup_stale_records!
    # Cables first (depend on elements)
    stale_cables = @network_map.network_cables.where(external_id: @stale_cable_external_ids)
    stale_cable_ids = stale_cables.pluck(:id)

    if stale_cable_ids.any?
      NetworkCablePoint.where(network_cable_id: stale_cable_ids).delete_all
      NetworkCableEvent.where(network_cable_id: stale_cable_ids).delete_all
      stale_cables.delete_all
    end

    # Elements (no further dependents after cables are removed)
    @network_map.map_elements.where(external_id: @stale_element_external_ids).delete_all
  end

  def replace_points!(cable, points)
    cable.network_cable_points.delete_all

    points.each do |point|
      cable.network_cable_points.create!(
        position: point[:position],
        x:        point[:lat],
        y:        point[:lng]
      )
    end
  end

  def create_snapshot!
    @network_map.network_map_snapshots.create!(
      label: @payload[:history_label].presence || "Autosave",
      state: {
        active_base_layer: @network_map.active_base_layer,
        elements:          @sanitized_elements,
        edges:             @sanitized_cables,
        draft_cable:       sanitize_draft_cable(@payload[:draft_cable]),
        history_index:     @payload[:history_index]
      }
    )
  end

  def validate_payload_uniqueness!
    assert_unique_external_ids!(elements_payload, :id, :elements)
    assert_unique_external_ids!(cables_payload, :id, :edges)
  end

  def assert_unique_external_ids!(list, field, section)
    values = list.map { |item| item[field].to_s.presence }.compact
    duplicates = values.group_by(&:itself).select { |_id, items| items.size > 1 }.keys
    return if duplicates.empty?

    raise ActiveRecord::RecordInvalid.new(
      build_error_record(section => "external_id duplicado no payload: #{duplicates.join(', ')}")
    )
  end

  def resolve_element!(external_id, field:)
    return nil if external_id.blank?

    element = @element_by_external_id[external_id.to_s]
    return element if element.present?

    raise ActiveRecord::RecordInvalid.new(
      build_error_record(field => "Element '#{external_id}' não encontrado no payload/mapa")
    )
  end

  def sanitize_points!(points_payload)
    points = Array(points_payload).map.with_index do |point, index|
      {
        position: point[:position] || index,
        lat:      point[:lat],
        lng:      point[:lng]
      }
    end

    if points.length < 2
      raise ActiveRecord::RecordInvalid.new(build_error_record(points: "É necessário ao menos 2 pontos"))
    end

    points.sort_by { |point| point[:position].to_i }
  end

  def build_element_attrs(elem)
    {
      mappable_type:  elem[:mappable_type],
      mappable_id:    elem[:mappable_id],
      lat:            elem[:lat],
      lng:            elem[:lng],
      icon_override:  elem[:icon_override],
      color_override: elem[:color_override],
      label_override: elem[:label_override],
      size_override:  elem[:size_override],
      collapsed:      elem[:collapsed] || false,
      display_order:  elem[:display_order] || 0,
      metadata:       sanitize_metadata(elem[:metadata])
    }
  end

  def sanitize_metadata(metadata)
    metadata.is_a?(Hash) ? metadata.deep_dup : {}
  end

  def sanitize_draft_cable(draft_cable)
    return {} unless draft_cable.is_a?(Hash)

    draft_cable.deep_dup
  end

  def sanitized_element_payload(element)
    MapElements::PayloadBuilder.new(map_element: element).call
  end

  def sanitized_cable_payload(cable, points)
    {
      id:                cable.external_id,
      label:             cable.label,
      cable_type:        cable.cable_type,
      status:            cable.status,
      source_element_id: cable.source_element&.external_id,
      target_element_id: cable.target_element&.external_id,
      color:             cable.color,
      weight:            cable.weight,
      pattern:           cable.pattern,
      metadata:          sanitize_metadata(cable.metadata),
      points:            points
    }
  end

  def build_error_record(details)
    NetworkMap.new.tap do |record|
      details.each { |field, message| record.errors.add(field, message) }
    end
  end

  def elements_payload
    Array(@payload[:elements])
  end

  def cables_payload
    Array(@payload[:edges])
  end
end
