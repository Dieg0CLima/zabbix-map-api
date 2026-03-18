class RefactorInventoryToNetboxStyleModel < ActiveRecord::Migration[8.0]
  class MigrationOrganization < ApplicationRecord
    self.table_name = "organizations"
  end

  class MigrationNetworkMap < ApplicationRecord
    self.table_name = "network_maps"
  end

  class MigrationMapPop < ApplicationRecord
    self.table_name = "map_pops"
  end

  class MigrationMapNode < ApplicationRecord
    self.table_name = "map_nodes"
  end

  class MigrationZabbixConnection < ApplicationRecord
    self.table_name = "zabbix_connections"
  end

  class MigrationSite < ApplicationRecord
    self.table_name = "sites"
  end

  class MigrationDevice < ApplicationRecord
    self.table_name = "devices"
  end

  def up
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
    add_index :sites, [:organization_id, :slug], unique: true
    add_index :sites, [:organization_id, :name]

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
    add_index :devices, [:organization_id, :name]
    add_index :devices, [:organization_id, :hostname]
    add_index :devices, [:organization_id, :serial_number]

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
    add_index :device_interfaces, [:device_id, :name], unique: true

    add_column :network_maps, :metadata, :jsonb, null: false, default: {}

    add_reference :map_nodes, :mappable, polymorphic: true, null: true
    add_column :map_nodes, :width, :integer
    add_column :map_nodes, :height, :integer
    add_column :map_nodes, :label_override, :string
    add_column :map_nodes, :visible, :boolean, null: false, default: true
    add_column :map_nodes, :collapsed, :boolean, null: false, default: false

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
    add_index :map_edges, [:network_map_id, :source_node_id, :target_node_id, :edge_type], unique: true, name: "idx_map_edges_uniqueness"

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
    add_index :zabbix_links, [:linkable_type, :linkable_id]
    add_index :zabbix_links, [:organization_id, :zabbix_connection_id, :resource_type, :external_id], unique: true, name: "idx_zabbix_links_external_uniqueness"

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

    migrate_legacy_sites_and_devices!
    backfill_map_node_mappables!
    backfill_legacy_zabbix_links!
  end

  def down
    drop_table :map_monitoring_bindings
    drop_table :zabbix_links
    drop_table :map_edges

    remove_column :map_nodes, :collapsed
    remove_column :map_nodes, :visible
    remove_column :map_nodes, :label_override
    remove_column :map_nodes, :height
    remove_column :map_nodes, :width
    remove_reference :map_nodes, :mappable, polymorphic: true

    remove_column :network_maps, :metadata

    drop_table :device_interfaces
    drop_table :devices
    drop_table :sites
  end

  private

  def migrate_legacy_sites_and_devices!
    say_with_time "Migrating legacy POPs to sites and nodes to devices" do
      MigrationMapPop.find_each do |legacy_pop|
        site = MigrationSite.create!(
          organization_id: network_map_org_id(legacy_pop.network_map_id),
          name: legacy_pop.name,
          slug: unique_site_slug(network_map_org_id(legacy_pop.network_map_id), legacy_pop.name),
          lat: legacy_pop.lat,
          lng: legacy_pop.lng,
          metadata: {
            legacy_map_pop_id: legacy_pop.id,
            legacy_external_id: legacy_pop.external_id,
            legacy_network_map_id: legacy_pop.network_map_id,
            color: legacy_pop.color
          }.merge(legacy_pop.metadata || {})
        )

        MigrationMapNode.where(map_pop_id: legacy_pop.id).find_each do |legacy_node|
          MigrationDevice.create!(
            organization_id: site.organization_id,
            site_id: site.id,
            name: legacy_node.label,
            role: normalize_role(legacy_node.node_kind),
            status: "active",
            metadata: {
              legacy_map_node_id: legacy_node.id,
              legacy_external_id: legacy_node.external_id,
              legacy_node_kind: legacy_node.node_kind,
              icon: legacy_node.icon,
              color: legacy_node.color,
              position: { x: legacy_node.x, y: legacy_node.y, lat: legacy_node.lat, lng: legacy_node.lng }
            }.merge(legacy_node.metadata || {})
          )
        end
      end

      MigrationMapNode.where(map_pop_id: nil).find_each do |legacy_node|
        org_id = network_map_org_id(legacy_node.network_map_id)
        MigrationDevice.create!(
          organization_id: org_id,
          name: legacy_node.label,
          role: normalize_role(legacy_node.node_kind),
          status: "active",
          metadata: {
            legacy_map_node_id: legacy_node.id,
            legacy_external_id: legacy_node.external_id,
            legacy_node_kind: legacy_node.node_kind,
            icon: legacy_node.icon,
            color: legacy_node.color,
            position: { x: legacy_node.x, y: legacy_node.y, lat: legacy_node.lat, lng: legacy_node.lng }
          }.merge(legacy_node.metadata || {})
        )
      end
    end
  end

  def backfill_map_node_mappables!
    say_with_time "Backfilling map node mappables" do
      MigrationMapNode.find_each do |legacy_node|
        device = MigrationDevice.find_by("metadata ->> 'legacy_map_node_id' = ?", legacy_node.id.to_s)
        next if device.blank?

        legacy_node.update_columns(
          mappable_type: "Device",
          mappable_id: device.id,
          label_override: legacy_node.label,
          width: legacy_node.size,
          height: legacy_node.size,
          visible: true,
          collapsed: false
        )
      end
    end
  end

  def backfill_legacy_zabbix_links!
    say_with_time "Backfilling legacy Zabbix links" do
      MigrationMapNode.where.not(zabbix_host_id: nil).find_each do |legacy_node|
        device = MigrationDevice.find_by("metadata ->> 'legacy_map_node_id' = ?", legacy_node.id.to_s)
        next if device.blank?

        map = MigrationNetworkMap.find(legacy_node.network_map_id)
        next if map.zabbix_connection_id.blank?

        MigrationSite.connection.execute <<~SQL
          INSERT INTO zabbix_links
            (organization_id, zabbix_connection_id, linkable_type, linkable_id, resource_type, external_id, name, metadata, created_at, updated_at)
          VALUES
            (
              #{map.organization_id},
              #{map.zabbix_connection_id},
              'Device',
              #{device.id},
              'host',
              '#{legacy_node.zabbix_host_id}',
              #{MigrationSite.connection.quote(legacy_node.label)},
              '#{{ legacy_map_node_id: legacy_node.id }.to_json}'::jsonb,
              CURRENT_TIMESTAMP,
              CURRENT_TIMESTAMP
            )
          ON CONFLICT DO NOTHING
        SQL
      end
    end
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
    return "generic" if node_kind.blank?

    node_kind.to_s
  end
end
