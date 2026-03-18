class RefactorInventoryToNetboxStyleModel < ActiveRecord::Migration[8.0]
  class MigrationNetworkMap < ApplicationRecord
    self.table_name = "network_maps"
  end

  class MigrationMapPop < ApplicationRecord
    self.table_name = "map_pops"
  end

  class MigrationMapNode < ApplicationRecord
    self.table_name = "map_nodes"
  end

  class MigrationSite < ApplicationRecord
    self.table_name = "sites"
  end

  class MigrationDevice < ApplicationRecord
    self.table_name = "devices"
  end

  def up
    ensure_sites_table!
    ensure_devices_table!
    ensure_device_interfaces_table!
    ensure_network_maps_metadata!
    ensure_map_nodes_projection_columns!
    ensure_map_edges_table!
    ensure_zabbix_links_table!
    ensure_map_monitoring_bindings_table!

    migrate_legacy_sites_and_devices!
    backfill_map_node_mappables!
    backfill_legacy_zabbix_links!
  end

  def down
    drop_table :map_monitoring_bindings, if_exists: true
    drop_table :zabbix_links, if_exists: true
    drop_table :map_edges, if_exists: true

    remove_column :map_nodes, :collapsed if column_exists?(:map_nodes, :collapsed)
    remove_column :map_nodes, :visible if column_exists?(:map_nodes, :visible)
    remove_column :map_nodes, :label_override if column_exists?(:map_nodes, :label_override)
    remove_column :map_nodes, :height if column_exists?(:map_nodes, :height)
    remove_column :map_nodes, :width if column_exists?(:map_nodes, :width)
    remove_column :map_nodes, :mappable_type if column_exists?(:map_nodes, :mappable_type)
    remove_column :map_nodes, :mappable_id if column_exists?(:map_nodes, :mappable_id)

    remove_column :network_maps, :metadata if column_exists?(:network_maps, :metadata)

    drop_table :device_interfaces, if_exists: true
    drop_table :devices, if_exists: true
    drop_table :sites, if_exists: true
  end

  private

  def ensure_sites_table!
    unless table_exists?(:sites)
      create_table :sites do |t|
        t.references :organization, null: false, foreign_key: true
        t.string :name, null: false
        t.string :slug, null: false
        t.text :description
        t.string :address
        t.string :city
        t.string :state
        t.decimal :lat, precision: 10, scale: 6
        t.decimal :lng, precision: 10, scale: 6
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
    else
      add_reference :sites, :organization, foreign_key: true unless column_exists?(:sites, :organization_id)
      add_column :sites, :name, :string unless column_exists?(:sites, :name)
      add_column :sites, :slug, :string unless column_exists?(:sites, :slug)
      add_column :sites, :description, :text unless column_exists?(:sites, :description)
      add_column :sites, :address, :string unless column_exists?(:sites, :address)
      add_column :sites, :city, :string unless column_exists?(:sites, :city)
      add_column :sites, :state, :string unless column_exists?(:sites, :state)
      add_column :sites, :lat, :decimal, precision: 10, scale: 6 unless column_exists?(:sites, :lat)
      add_column :sites, :lng, :decimal, precision: 10, scale: 6 unless column_exists?(:sites, :lng)
      add_column :sites, :metadata, :jsonb, null: false, default: {} unless column_exists?(:sites, :metadata)
      add_timestamps :sites, null: true unless column_exists?(:sites, :created_at) || column_exists?(:sites, :updated_at)
    end

    add_index :sites, [:organization_id, :slug], unique: true unless index_exists?(:sites, [:organization_id, :slug], unique: true)
    add_index :sites, [:organization_id, :name] unless index_exists?(:sites, [:organization_id, :name])
  end

  def ensure_devices_table!
    unless table_exists?(:devices)
      create_table :devices do |t|
        t.references :organization, null: false, foreign_key: true
        t.references :site, null: true, foreign_key: true
        t.string :name, null: false
        t.string :hostname
        t.string :role, null: false, default: "generic"
        t.string :vendor
        t.string :model
        t.string :serial_number
        t.string :management_ip
        t.string :status, null: false, default: "active"
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
    else
      add_reference :devices, :organization, foreign_key: true unless column_exists?(:devices, :organization_id)
      add_reference :devices, :site, foreign_key: true unless column_exists?(:devices, :site_id)
      add_column :devices, :name, :string unless column_exists?(:devices, :name)
      add_column :devices, :hostname, :string unless column_exists?(:devices, :hostname)
      add_column :devices, :role, :string, null: false, default: "generic" unless column_exists?(:devices, :role)
      add_column :devices, :vendor, :string unless column_exists?(:devices, :vendor)
      add_column :devices, :model, :string unless column_exists?(:devices, :model)
      add_column :devices, :serial_number, :string unless column_exists?(:devices, :serial_number)
      add_column :devices, :management_ip, :string unless column_exists?(:devices, :management_ip)
      add_column :devices, :status, :string, null: false, default: "active" unless column_exists?(:devices, :status)
      add_column :devices, :metadata, :jsonb, null: false, default: {} unless column_exists?(:devices, :metadata)
      add_timestamps :devices, null: true unless column_exists?(:devices, :created_at) || column_exists?(:devices, :updated_at)
    end

    add_index :devices, [:organization_id, :name] unless index_exists?(:devices, [:organization_id, :name])
    add_index :devices, [:organization_id, :hostname] unless index_exists?(:devices, [:organization_id, :hostname])
    add_index :devices, [:organization_id, :serial_number] unless index_exists?(:devices, [:organization_id, :serial_number])
  end

  def ensure_device_interfaces_table!
    unless table_exists?(:device_interfaces)
      create_table :device_interfaces do |t|
        t.references :device, null: false, foreign_key: true
        t.string :name, null: false
        t.string :interface_type
        t.string :description
        t.boolean :enabled, null: false, default: true
        t.boolean :management, null: false, default: false
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
    else
      add_reference :device_interfaces, :device, foreign_key: true unless column_exists?(:device_interfaces, :device_id)
      add_column :device_interfaces, :name, :string unless column_exists?(:device_interfaces, :name)
      add_column :device_interfaces, :interface_type, :string unless column_exists?(:device_interfaces, :interface_type)
      add_column :device_interfaces, :description, :string unless column_exists?(:device_interfaces, :description)
      add_column :device_interfaces, :enabled, :boolean, null: false, default: true unless column_exists?(:device_interfaces, :enabled)
      add_column :device_interfaces, :management, :boolean, null: false, default: false unless column_exists?(:device_interfaces, :management)
      add_column :device_interfaces, :metadata, :jsonb, null: false, default: {} unless column_exists?(:device_interfaces, :metadata)
      add_timestamps :device_interfaces, null: true unless column_exists?(:device_interfaces, :created_at) || column_exists?(:device_interfaces, :updated_at)
    end

    add_index :device_interfaces, [:device_id, :name], unique: true unless index_exists?(:device_interfaces, [:device_id, :name], unique: true)
  end

  def ensure_network_maps_metadata!
    add_column :network_maps, :metadata, :jsonb, null: false, default: {} unless column_exists?(:network_maps, :metadata)
  end

  def ensure_map_nodes_projection_columns!
    add_column :map_nodes, :mappable_type, :string unless column_exists?(:map_nodes, :mappable_type)
    add_column :map_nodes, :mappable_id, :bigint unless column_exists?(:map_nodes, :mappable_id)
    add_index :map_nodes, [:mappable_type, :mappable_id] unless index_exists?(:map_nodes, [:mappable_type, :mappable_id])
    add_column :map_nodes, :width, :integer unless column_exists?(:map_nodes, :width)
    add_column :map_nodes, :height, :integer unless column_exists?(:map_nodes, :height)
    add_column :map_nodes, :label_override, :string unless column_exists?(:map_nodes, :label_override)
    add_column :map_nodes, :visible, :boolean, null: false, default: true unless column_exists?(:map_nodes, :visible)
    add_column :map_nodes, :collapsed, :boolean, null: false, default: false unless column_exists?(:map_nodes, :collapsed)
  end

  def ensure_map_edges_table!
    unless table_exists?(:map_edges)
      create_table :map_edges do |t|
        t.references :network_map, null: false, foreign_key: true
        t.references :source_node, null: false, foreign_key: { to_table: :map_nodes }
        t.references :target_node, null: false, foreign_key: { to_table: :map_nodes }
        t.string :edge_type, null: false, default: "logical"
        t.string :label
        t.string :color
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
    end

    unless index_exists?(:map_edges, [:network_map_id, :source_node_id, :target_node_id, :edge_type], unique: true, name: "idx_map_edges_uniqueness")
      add_index :map_edges, [:network_map_id, :source_node_id, :target_node_id, :edge_type], unique: true, name: "idx_map_edges_uniqueness"
    end
  end

  def ensure_zabbix_links_table!
    unless table_exists?(:zabbix_links)
      create_table :zabbix_links do |t|
        t.references :organization, null: false, foreign_key: true
        t.references :zabbix_connection, null: false, foreign_key: true
        t.string :linkable_type, null: false
        t.bigint :linkable_id, null: false
        t.string :resource_type, null: false
        t.string :external_id, null: false
        t.string :external_key
        t.string :name
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
    end

    add_index :zabbix_links, [:linkable_type, :linkable_id] unless index_exists?(:zabbix_links, [:linkable_type, :linkable_id])
    unless index_exists?(:zabbix_links, [:organization_id, :zabbix_connection_id, :resource_type, :external_id], unique: true, name: "idx_zabbix_links_external_uniqueness")
      add_index :zabbix_links, [:organization_id, :zabbix_connection_id, :resource_type, :external_id], unique: true, name: "idx_zabbix_links_external_uniqueness"
    end
  end

  def ensure_map_monitoring_bindings_table!
    return if table_exists?(:map_monitoring_bindings)

    create_table :map_monitoring_bindings do |t|
      t.references :map_node, null: false, foreign_key: true
      t.references :zabbix_link, null: true, foreign_key: true
      t.string :metric_type, null: false
      t.string :display_mode, null: false, default: "badge"
      t.string :label
      t.string :severity_source
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end

  def migrate_legacy_sites_and_devices!
    return unless table_exists?(:map_pops) && table_exists?(:map_nodes) && table_exists?(:sites) && table_exists?(:devices)

    say_with_time "Migrating legacy POPs to sites and nodes to devices" do
      MigrationMapPop.find_each do |legacy_pop|
        organization_id = network_map_org_id(legacy_pop.network_map_id)
        site = find_or_create_site_for_legacy_pop(legacy_pop, organization_id)

        MigrationMapNode.where(map_pop_id: legacy_pop.id).find_each do |legacy_node|
          next if find_or_match_device_for_legacy_node(legacy_node, site.organization_id, site.id).present?

          MigrationDevice.create!(
            device_create_attributes(legacy_node, site.organization_id, site.id)
          )
        end
      end

      MigrationMapNode.where(map_pop_id: nil).find_each do |legacy_node|
        organization_id = network_map_org_id(legacy_node.network_map_id)
        next if find_or_match_device_for_legacy_node(legacy_node, organization_id, nil).present?

        MigrationDevice.create!(
          device_create_attributes(legacy_node, organization_id, nil)
        )
      end
    end
  end

  def backfill_map_node_mappables!
    return unless table_exists?(:map_nodes) && table_exists?(:devices)
    return unless column_exists?(:map_nodes, :mappable_type) && column_exists?(:map_nodes, :mappable_id)

    say_with_time "Backfilling map node mappables" do
      MigrationMapNode.find_each do |legacy_node|
        next if legacy_node.mappable_type.present? && legacy_node.mappable_id.present?

        device = find_device_by_legacy_node(legacy_node)
        next if device.blank?

        legacy_node.update_columns(
          mappable_type: "Device",
          mappable_id: device.id,
          label_override: legacy_node.try(:label_override).presence || legacy_node.label,
          width: legacy_node.try(:width).presence || legacy_node.size,
          height: legacy_node.try(:height).presence || legacy_node.size,
          visible: legacy_node.try(:visible).nil? ? true : legacy_node.visible,
          collapsed: legacy_node.try(:collapsed).nil? ? false : legacy_node.collapsed
        )
      end
    end
  end

  def backfill_legacy_zabbix_links!
    return unless table_exists?(:map_nodes) && table_exists?(:devices) && table_exists?(:zabbix_links)

    say_with_time "Backfilling legacy Zabbix links" do
      MigrationMapNode.where.not(zabbix_host_id: nil).find_each do |legacy_node|
        device = find_device_by_legacy_node(legacy_node)
        next if device.blank?

        map = MigrationNetworkMap.find_by(id: legacy_node.network_map_id)
        next if map.blank? || map.zabbix_connection_id.blank?
        next if MigrationSite.connection.select_value(existing_zabbix_link_sql(map, device, legacy_node)).present?

        MigrationSite.connection.execute(insert_zabbix_link_sql(map, device, legacy_node))
      end
    end
  end



  def find_or_create_site_for_legacy_pop(legacy_pop, organization_id)
    site = find_site_by_legacy_pop(legacy_pop, organization_id)
    return site if site.present?

    MigrationSite.create!(site_create_attributes(legacy_pop, organization_id))
  end

  def find_or_match_device_for_legacy_node(legacy_node, organization_id, site_id)
    find_device_by_legacy_node(legacy_node, organization_id, site_id)
  end

  def site_create_attributes(legacy_pop, organization_id)
    attrs = {
      organization_id:,
      name: legacy_pop.name,
      slug: unique_site_slug(organization_id, legacy_pop.name),
      lat: legacy_pop.lat,
      lng: legacy_pop.lng,
      metadata: {
        legacy_map_pop_id: legacy_pop.id,
        legacy_external_id: legacy_pop.external_id,
        legacy_network_map_id: legacy_pop.network_map_id,
        color: legacy_pop.color
      }.merge(legacy_pop.metadata || {})
    }

    attrs[:external_id] = legacy_pop.external_id.presence || "site-#{legacy_pop.id}" if column_exists?(:sites, :external_id)
    attrs[:status] = "active" if column_exists?(:sites, :status)
    attrs[:site_type] = "pop" if column_exists?(:sites, :site_type)
    attrs[:description] = legacy_pop.metadata["description"] if column_exists?(:sites, :description) && legacy_pop.metadata.is_a?(Hash)
    attrs[:address] = legacy_pop.metadata["address"] if column_exists?(:sites, :address) && legacy_pop.metadata.is_a?(Hash)
    attrs[:city] = legacy_pop.metadata["city"] if column_exists?(:sites, :city) && legacy_pop.metadata.is_a?(Hash)
    attrs[:state] = legacy_pop.metadata["state"] if column_exists?(:sites, :state) && legacy_pop.metadata.is_a?(Hash)

    attrs
  end

  def device_create_attributes(legacy_node, organization_id, site_id)
    attrs = {
      organization_id:,
      name: legacy_node.label,
      role: normalize_role(legacy_node.node_kind),
      status: "active",
      metadata: build_device_metadata(legacy_node)
    }

    attrs[:site_id] = site_id if site_id.present? && column_exists?(:devices, :site_id)
    attrs[:hostname] = legacy_node.zabbix_ref if column_exists?(:devices, :hostname) && legacy_node.zabbix_ref.present?
    attrs[:external_id] = legacy_node.external_id.presence || "device-#{legacy_node.id}" if column_exists?(:devices, :external_id)
    attrs[:device_type] = normalize_role(legacy_node.node_kind) if column_exists?(:devices, :device_type)

    attrs
  end

  def find_site_by_legacy_pop(legacy_pop, organization_id)
    site = MigrationSite.find_by("metadata ->> 'legacy_map_pop_id' = ?", legacy_pop.id.to_s)
    return site if site.present?

    scope = MigrationSite.where(organization_id:, name: legacy_pop.name)
    scope = scope.where(external_id: legacy_pop.external_id) if column_exists?(:sites, :external_id) && legacy_pop.external_id.present?
    site = scope.first || MigrationSite.where(organization_id:, name: legacy_pop.name).first
    return site if site.blank?

    backfill_site_metadata!(site, legacy_pop)
    site
  end

  def find_device_by_legacy_node(legacy_node, organization_id = nil, site_id = nil)
    device = MigrationDevice.find_by("metadata ->> 'legacy_map_node_id' = ?", legacy_node.id.to_s)
    return device if device.present?

    return if organization_id.blank?

    scope = MigrationDevice.where(organization_id:, name: legacy_node.label)
    scope = scope.where(site_id:) if site_id.present? && column_exists?(:devices, :site_id)
    scope = scope.where(external_id: legacy_node.external_id) if column_exists?(:devices, :external_id) && legacy_node.external_id.present?
    device = scope.first || MigrationDevice.where(organization_id:, name: legacy_node.label).first
    return device if device.blank?

    backfill_device_metadata!(device, legacy_node)
    device
  end


  def backfill_site_metadata!(site, legacy_pop)
    metadata = (site.metadata || {}).dup
    metadata["legacy_map_pop_id"] ||= legacy_pop.id
    metadata["legacy_external_id"] ||= legacy_pop.external_id
    metadata["legacy_network_map_id"] ||= legacy_pop.network_map_id
    metadata["color"] ||= legacy_pop.color
    site.update_columns(metadata:) if site.has_attribute?(:metadata)
  end

  def backfill_device_metadata!(device, legacy_node)
    metadata = (device.metadata || {}).dup
    metadata["legacy_map_node_id"] ||= legacy_node.id
    metadata["legacy_external_id"] ||= legacy_node.external_id
    metadata["legacy_node_kind"] ||= legacy_node.node_kind
    metadata["icon"] ||= legacy_node.icon
    metadata["color"] ||= legacy_node.color
    metadata["position"] ||= {
      x: legacy_node.x,
      y: legacy_node.y,
      lat: legacy_node.lat,
      lng: legacy_node.lng
    }
    device.update_columns(metadata:) if device.has_attribute?(:metadata)
  end

  def build_device_metadata(legacy_node)
    {
      legacy_map_node_id: legacy_node.id,
      legacy_external_id: legacy_node.external_id,
      legacy_node_kind: legacy_node.node_kind,
      icon: legacy_node.icon,
      color: legacy_node.color,
      position: { x: legacy_node.x, y: legacy_node.y, lat: legacy_node.lat, lng: legacy_node.lng }
    }.merge(legacy_node.metadata || {})
  end

  def existing_zabbix_link_sql(map, device, legacy_node)
    <<~SQL.squish
      SELECT id FROM zabbix_links
      WHERE organization_id = #{map.organization_id}
        AND zabbix_connection_id = #{map.zabbix_connection_id}
        AND resource_type = 'host'
        AND external_id = #{MigrationSite.connection.quote(legacy_node.zabbix_host_id.to_s)}
        AND linkable_type = 'Device'
        AND linkable_id = #{device.id}
      LIMIT 1
    SQL
  end

  def insert_zabbix_link_sql(map, device, legacy_node)
    <<~SQL
      INSERT INTO zabbix_links
        (organization_id, zabbix_connection_id, linkable_type, linkable_id, resource_type, external_id, name, metadata, created_at, updated_at)
      VALUES
        (
          #{map.organization_id},
          #{map.zabbix_connection_id},
          'Device',
          #{device.id},
          'host',
          #{MigrationSite.connection.quote(legacy_node.zabbix_host_id.to_s)},
          #{MigrationSite.connection.quote(legacy_node.label)},
          #{MigrationSite.connection.quote({ legacy_map_node_id: legacy_node.id }.to_json)}::jsonb,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      ON CONFLICT DO NOTHING
    SQL
  end

  def network_map_org_id(network_map_id)
    MigrationNetworkMap.find(network_map_id).organization_id
  end

  def unique_site_slug(organization_id, name)
    base = name.to_s.parameterize.presence || "site"
    slug = base
    counter = 2

    while MigrationSite.exists?(organization_id:, slug:)
      slug = "#{base}-#{counter}"
      counter += 1
    end

    slug
  end

  def normalize_role(node_kind)
    node_kind.present? ? node_kind.to_s : "generic"
  end
end
