class MigratePopAndNodesToDomainEntities < ActiveRecord::Migration[8.0]
  # Data migration: creates canonical Site/Device records for each MapPop/MapNode,
  # then creates MapElements to represent their presence in each map.
  #
  # Strategy:
  #   - Each MapPop → one Site per (organization, name). If two maps in the same org
  #     share a POP with the same name, they share one Site (deduplicated by name).
  #   - Each MapNode → one Device per (organization, label). Nodes with node_kind='text'
  #     become Device with device_type='label' to preserve them visually.
  #   - MapElements are created for every pop/node present in each map.
  #   - NetworkCable endpoints are migrated to source_element_id/target_element_id.
  #   - Legacy pop/node IDs on cables are nullified after successful migration.
  #
  # Ambiguity note:
  #   MapPops are scoped to a single map and have no organization-level uniqueness.
  #   Two different maps may have POPs with the same name representing different
  #   physical sites. To avoid false merging, we scope Site deduplication to
  #   (organization_id, name) and treat each unique name as one canonical Site.
  #   If finer control is needed, Sites can be split manually after migration.
  def up
    ActiveRecord::Base.transaction do
      migrate_pops_to_sites!
      migrate_nodes_to_devices!
      migrate_cable_endpoints!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "This migration transforms live domain data and cannot be reversed automatically."
  end

  private

  def migrate_pops_to_sites!
    # site_cache: { organization_id => { pop_name => site_id } }
    site_cache = Hash.new { |h, k| h[k] = {} }

    execute(<<~SQL).each do |pop|
      SELECT mp.id, mp.name, mp.external_id, mp.lat, mp.lng, mp.color, mp.metadata,
             mp.network_map_id, nm.organization_id
      FROM map_pops mp
      INNER JOIN network_maps nm ON nm.id = mp.network_map_id
      ORDER BY mp.id
    SQL
      org_id    = pop["organization_id"].to_i
      pop_name  = pop["name"]
      site_key  = pop_name.downcase.strip

      site_id = site_cache[org_id][site_key] ||= find_or_create_site(
        organization_id: org_id,
        name:            pop_name,
        lat:             pop["lat"],
        lng:             pop["lng"],
        external_id:     "site-#{SecureRandom.uuid}"
      )

      create_map_element_for_pop(
        network_map_id: pop["network_map_id"].to_i,
        site_id:        site_id,
        pop:            pop
      )
    end
  end

  def migrate_nodes_to_devices!
    # device_cache: { organization_id => { node_label => device_id } }
    device_cache = Hash.new { |h, k| h[k] = {} }

    # Include site_id via the pop→site mapping already in map_elements
    execute(<<~SQL).each do |node|
      SELECT mn.id, mn.label, mn.external_id, mn.node_kind, mn.lat, mn.lng,
             mn.icon, mn.color, mn.size, mn.zabbix_ref, mn.metadata,
             mn.network_map_id, mn.map_pop_id, nm.organization_id,
             me.id AS parent_element_id
      FROM map_nodes mn
      INNER JOIN network_maps nm ON nm.id = mn.network_map_id
      LEFT JOIN map_pops mp ON mp.id = mn.map_pop_id
      LEFT JOIN map_elements me ON (me.mappable_type = 'Site' AND me.network_map_id = mn.network_map_id
                                    AND me.mappable_id = (
                                      SELECT s.id FROM sites s
                                      INNER JOIN map_elements me2 ON me2.mappable_id = s.id
                                        AND me2.mappable_type = 'Site'
                                        AND me2.network_map_id = mn.network_map_id
                                      WHERE LOWER(s.name) = LOWER(mp.name)
                                        AND s.organization_id = nm.organization_id
                                      LIMIT 1
                                    ))
      ORDER BY mn.id
    SQL
      org_id     = node["organization_id"].to_i
      node_label = node["label"]
      device_key = node_label.downcase.strip

      device_id = device_cache[org_id][device_key] ||= find_or_create_device(
        organization_id: org_id,
        name:            node_label,
        device_type:     map_device_type(node["node_kind"]),
        zabbix_ref:      node["zabbix_ref"],
        external_id:     "device-#{SecureRandom.uuid}"
      )

      create_map_element_for_node(
        network_map_id:    node["network_map_id"].to_i,
        device_id:         device_id,
        node:              node
      )
    end
  end

  def migrate_cable_endpoints!
    execute(<<~SQL).each do |cable|
      SELECT nc.id,
             nc.source_pop_id, nc.target_pop_id,
             nc.source_node_id, nc.target_node_id,
             nc.network_map_id
      FROM network_cables nc
      WHERE nc.source_pop_id IS NOT NULL
         OR nc.target_pop_id IS NOT NULL
         OR nc.source_node_id IS NOT NULL
         OR nc.target_node_id IS NOT NULL
    SQL
      cable_id       = cable["id"].to_i
      map_id         = cable["network_map_id"].to_i
      source_elem_id = resolve_cable_endpoint(map_id, cable["source_pop_id"], cable["source_node_id"])
      target_elem_id = resolve_cable_endpoint(map_id, cable["target_pop_id"], cable["target_node_id"])

      next unless source_elem_id || target_elem_id

      execute(<<~SQL)
        UPDATE network_cables
        SET source_element_id = #{source_elem_id.nil? ? 'NULL' : source_elem_id},
            target_element_id = #{target_elem_id.nil? ? 'NULL' : target_elem_id}
        WHERE id = #{cable_id}
      SQL
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Helpers
  # ──────────────────────────────────────────────────────────────────────────

  def find_or_create_site(organization_id:, name:, lat:, lng:, external_id:)
    result = execute(<<~SQL).first
      SELECT id FROM sites
      WHERE organization_id = #{organization_id}
        AND LOWER(name) = LOWER(#{quote(name)})
      LIMIT 1
    SQL

    return result["id"].to_i if result

    execute(<<~SQL)
      INSERT INTO sites (organization_id, external_id, name, lat, lng, status, metadata, created_at, updated_at)
      VALUES (
        #{organization_id},
        #{quote(external_id)},
        #{quote(name)},
        #{lat.present? ? lat : 'NULL'},
        #{lng.present? ? lng : 'NULL'},
        'active',
        '{}',
        NOW(), NOW()
      )
    SQL

    execute("SELECT lastval()").first["lastval"].to_i
  end

  def find_or_create_device(organization_id:, name:, device_type:, zabbix_ref:, external_id:)
    result = execute(<<~SQL).first
      SELECT id FROM devices
      WHERE organization_id = #{organization_id}
        AND LOWER(name) = LOWER(#{quote(name)})
      LIMIT 1
    SQL

    return result["id"].to_i if result

    execute(<<~SQL)
      INSERT INTO devices (organization_id, external_id, name, device_type, zabbix_ref, status, metadata, created_at, updated_at)
      VALUES (
        #{organization_id},
        #{quote(external_id)},
        #{quote(name)},
        #{quote(device_type)},
        #{zabbix_ref.present? ? quote(zabbix_ref) : 'NULL'},
        'active',
        '{}',
        NOW(), NOW()
      )
    SQL

    execute("SELECT lastval()").first["lastval"].to_i
  end

  def create_map_element_for_pop(network_map_id:, site_id:, pop:)
    execute(<<~SQL)
      INSERT INTO map_elements (
        network_map_id, mappable_type, mappable_id, external_id,
        lat, lng, color_override, metadata, collapsed, display_order,
        created_at, updated_at
      )
      VALUES (
        #{network_map_id},
        'Site',
        #{site_id},
        #{quote("elem-#{pop['external_id']}")},
        #{pop['lat']}, #{pop['lng']},
        #{pop['color'].present? ? quote(pop['color']) : 'NULL'},
        #{pop['metadata'].present? ? quote(pop['metadata']) : "'{}'"},
        false, 0,
        NOW(), NOW()
      )
      ON CONFLICT (network_map_id, mappable_type, mappable_id) DO NOTHING
    SQL
  end

  def create_map_element_for_node(network_map_id:, device_id:, node:)
    execute(<<~SQL)
      INSERT INTO map_elements (
        network_map_id, mappable_type, mappable_id, external_id,
        lat, lng, icon_override, color_override, size_override,
        label_override, metadata, collapsed, display_order,
        created_at, updated_at
      )
      VALUES (
        #{network_map_id},
        'Device',
        #{device_id},
        #{quote("elem-#{node['external_id']}")},
        #{node['lat']}, #{node['lng']},
        #{node['icon'].present? ? quote(node['icon']) : 'NULL'},
        #{node['color'].present? ? quote(node['color']) : 'NULL'},
        #{node['size'].present? ? node['size'] : 'NULL'},
        #{quote(node['label'])},
        #{node['metadata'].present? ? quote(node['metadata']) : "'{}'"},
        false, 0,
        NOW(), NOW()
      )
      ON CONFLICT (network_map_id, mappable_type, mappable_id) DO NOTHING
    SQL
  end

  def resolve_cable_endpoint(map_id, pop_id, node_id)
    if pop_id.present?
      result = execute(<<~SQL).first
        SELECT me.id FROM map_elements me
        INNER JOIN map_pops mp ON mp.id = #{pop_id.to_i}
        INNER JOIN sites s ON LOWER(s.name) = LOWER(mp.name)
          AND s.organization_id = (SELECT organization_id FROM network_maps WHERE id = #{map_id})
        WHERE me.network_map_id = #{map_id}
          AND me.mappable_type = 'Site'
          AND me.mappable_id = s.id
        LIMIT 1
      SQL
      return result["id"].to_i if result
    end

    if node_id.present?
      result = execute(<<~SQL).first
        SELECT me.id FROM map_elements me
        INNER JOIN map_nodes mn ON mn.id = #{node_id.to_i}
        INNER JOIN devices d ON LOWER(d.name) = LOWER(mn.label)
          AND d.organization_id = (SELECT organization_id FROM network_maps WHERE id = #{map_id})
        WHERE me.network_map_id = #{map_id}
          AND me.mappable_type = 'Device'
          AND me.mappable_id = d.id
        LIMIT 1
      SQL
      return result["id"].to_i if result
    end

    nil
  end

  def map_device_type(node_kind)
    mapping = {
      "switch"      => "switch",
      "router"      => "router",
      "server"      => "server",
      "firewall"    => "firewall",
      "gateway"     => "gateway",
      "endpoint"    => "endpoint",
      "olt"         => "olt",
      "cto"         => "cto",
      "splitter"    => "splitter",
      "zabbix_host" => "host",
      "text"        => "label"
    }
    mapping[node_kind] || node_kind
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
