class NetworkMaps::PersistEditorState
  # Service responsible for applying a full editor snapshot using incremental upserts.
  #
  # Key guarantees:
  # - no destroy_all (preserves control over FK order and avoids mass callback storms)
  # - stable internal IDs for records matched by external_id
  # - explicit validation when payload references missing external_ids
  # - stale records are removed in FK-safe order (cables -> nodes -> sites)
  # - all operations run in a single transaction with row lock on network_map
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload

    @site_by_external_id = {}
    @node_by_external_id = {}

    @sanitized_sites = []
    @sanitized_nodes = []
    @sanitized_cables = []
  end

  def call
    ActiveRecord::Base.transaction do
      @network_map.lock!

      validate_payload_uniqueness!
      update_map!

      upsert_sites!
      upsert_nodes!
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

  def upsert_sites!
    existing = @network_map.sites.index_by(&:external_id)
    payload_external_ids = []

    sites_payload.each do |site|
      external_id = site[:id].to_s
      payload_external_ids << external_id

      record = existing[external_id] || @network_map.sites.new(external_id:)
      record.assign_attributes(
        name: site[:name],
        lat: site[:lat],
        lng: site[:lng],
        color: site[:color],
        metadata: sanitize_metadata(site[:metadata])
      )
      record.save!

      @site_by_external_id[external_id] = record
      @sanitized_sites << sanitized_site_payload(record)
    end

    @stale_site_external_ids = existing.keys - payload_external_ids
  end

  def upsert_nodes!
    existing = @network_map.map_nodes.index_by(&:external_id)
    @existing_nodes_by_external_id = existing
    payload_external_ids = []

    nodes_payload.each do |node|
      external_id = node[:id].to_s
      payload_external_ids << external_id

      site = resolve_site!(node[:site_id], field: :site_id)
      attrs = build_node_attrs(node, site)

      record = existing[external_id] || @network_map.map_nodes.new(external_id:)
      record.assign_attributes(attrs)
      record.save!

      @node_by_external_id[external_id] = record
      @sanitized_nodes << sanitized_node_payload(record)
    end

    @stale_node_external_ids = existing.keys - payload_external_ids
  end

  def upsert_cables!
    existing = @network_map.network_cables.includes(:network_cable_points).index_by(&:external_id)
    payload_external_ids = []

    cables_payload.each do |cable|
      external_id = cable[:id].to_s
      payload_external_ids << external_id

      resolved = resolve_cable_endpoints!(cable)
      points = sanitize_points!(cable[:points])

      record = existing[external_id] || @network_map.network_cables.new(external_id:)
      record.assign_attributes(
        label: cable[:label],
        cable_type: cable[:cable_type] || "manual",
        status: cable[:status] || "planned",
        color: cable[:color],
        weight: cable[:weight],
        pattern: cable[:pattern],
        source_site: resolved[:source_site],
        target_site: resolved[:target_site],
        source_node: resolved[:source_node],
        target_node: resolved[:target_node],
        metadata: sanitize_metadata(cable[:metadata])
      )
      record.save!

      replace_points!(record, points)
      @sanitized_cables << sanitized_cable_payload(record, points)
    end

    @stale_cable_external_ids = existing.keys - payload_external_ids
  end

  def cleanup_stale_records!
    # 1) Cables first (depend on nodes/sites). We delete points directly for performance.
    stale_cables = @network_map.network_cables.where(external_id: @stale_cable_external_ids)
    stale_cable_ids = stale_cables.pluck(:id)

    if stale_cable_ids.any?
      NetworkCablePoint.where(network_cable_id: stale_cable_ids).delete_all
      NetworkCableEvent.where(network_cable_id: stale_cable_ids).delete_all if defined?(NetworkCableEvent)
      stale_cables.delete_all
    end

    # 2) Nodes next (depend on sites).
    @network_map.map_nodes.where(external_id: @stale_node_external_ids).delete_all

    # 3) Sites last.
    @network_map.sites.where(external_id: @stale_site_external_ids).delete_all
  end

  def replace_points!(cable, points)
    cable.network_cable_points.delete_all

    points.each do |point|
      cable.network_cable_points.create!(
        position: point[:position],
        x: point[:lat],
        y: point[:lng]
      )
    end
  end

  def create_snapshot!
    @network_map.network_map_snapshots.create!(
      label: @payload[:history_label].presence || "Autosave",
      state: {
        active_base_layer: @network_map.active_base_layer,
        sites: @sanitized_sites,
        markers: @sanitized_nodes,
        edges: @sanitized_cables,
        draft_cable: sanitize_draft_cable(@payload[:draft_cable]),
        history_index: @payload[:history_index]
      }
    )
  end

  def validate_payload_uniqueness!
    assert_unique_external_ids!(sites_payload, :id, :sites)
    assert_unique_external_ids!(nodes_payload, :id, :markers)
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

  def resolve_site!(external_id, field:)
    return nil if external_id.blank?

    site = @site_by_external_id[external_id.to_s]
    return site if site.present?

    raise ActiveRecord::RecordInvalid.new(
      build_error_record(field => "Site '#{external_id}' não encontrado no payload/mapa")
    )
  end

  def resolve_node!(external_id, field:)
    return nil if external_id.blank?

    node = @node_by_external_id[external_id.to_s] || @existing_nodes_by_external_id[external_id.to_s]
    return node if node.present?

    raise ActiveRecord::RecordInvalid.new(
      build_error_record(field => "Node '#{external_id}' não encontrado no payload/mapa")
    )
  end

  def resolve_cable_endpoints!(cable)
    {
      source_site: resolve_site!(cable[:source_site_id], field: :source_site_id),
      target_site: resolve_site!(cable[:target_site_id], field: :target_site_id),
      source_node: resolve_node!(cable[:source_node_id], field: :source_node_id),
      target_node: resolve_node!(cable[:target_node_id], field: :target_node_id)
    }
  end

  def sanitize_points!(points_payload)
    points = Array(points_payload).map.with_index do |point, index|
      {
        position: point[:position] || index,
        lat: point[:lat],
        lng: point[:lng]
      }
    end

    if points.length < 2
      raise ActiveRecord::RecordInvalid.new(build_error_record(points: "É necessário ao menos 2 pontos"))
    end

    points.sort_by { |point| point[:position].to_i }
  end

  def build_node_attrs(node, site)
    lat = node[:lat]
    lng = node[:lng]

    # map_nodes still has required x/y columns. We store lat/lng as canonical values
    # and mirror them into x/y strictly for legacy schema compatibility.
    {
      site:,
      label: node[:label],
      node_kind: node[:node_kind] || "switch",
      lat:,
      lng:,
      x: lat,
      y: lng,
      icon: node[:icon],
      color: node[:color],
      size: node[:size],
      zabbix_ref: node[:zabbix_ref],
      metadata: sanitize_metadata(node[:metadata])
    }
  end

  def sanitize_metadata(metadata)
    metadata.is_a?(Hash) ? metadata.deep_dup : {}
  end

  def sanitize_draft_cable(draft_cable)
    return {} unless draft_cable.is_a?(Hash)

    draft_cable.deep_dup
  end

  def sanitized_site_payload(site)
    {
      id: site.external_id,
      name: site.name,
      lat: site.lat,
      lng: site.lng,
      color: site.color,
      metadata: sanitize_metadata(site.metadata)
    }
  end

  def sanitized_node_payload(node)
    {
      id: node.external_id,
      site_id: node.site&.external_id,
      label: node.label,
      node_kind: node.node_kind,
      lat: node.lat,
      lng: node.lng,
      icon: node.icon,
      color: node.color,
      size: node.size,
      zabbix_ref: node.zabbix_ref,
      metadata: sanitize_metadata(node.metadata)
    }
  end

  def sanitized_cable_payload(cable, points)
    {
      id: cable.external_id,
      label: cable.label,
      cable_type: cable.cable_type,
      status: cable.status,
      source_site_id: cable.source_site&.external_id,
      target_site_id: cable.target_site&.external_id,
      source_node_id: cable.source_node&.external_id,
      target_node_id: cable.target_node&.external_id,
      color: cable.color,
      weight: cable.weight,
      pattern: cable.pattern,
      metadata: sanitize_metadata(cable.metadata),
      points:
    }
  end

  def build_error_record(details)
    NetworkMap.new.tap do |record|
      details.each { |field, message| record.errors.add(field, message) }
    end
  end

  def sites_payload
    Array(@payload[:sites])
  end

  def nodes_payload
    Array(@payload[:markers])
  end

  def cables_payload
    Array(@payload[:edges])
  end
end
