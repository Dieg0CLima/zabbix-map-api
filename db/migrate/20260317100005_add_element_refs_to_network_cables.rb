class AddElementRefsToNetworkCables < ActiveRecord::Migration[8.0]
  # Cables now connect MapElements instead of MapPops/MapNodes directly.
  # The legacy pop/node columns are kept for data safety during migration
  # and will be removed in a follow-up migration once the cutover is verified.
  def change
    unless column_exists?(:network_cables, :source_element_id)
      add_column :network_cables, :source_element_id, :bigint
    end

    unless column_exists?(:network_cables, :target_element_id)
      add_column :network_cables, :target_element_id, :bigint
    end

    add_index :network_cables, :source_element_id, if_not_exists: true
    add_index :network_cables, :target_element_id, if_not_exists: true

    add_index :network_cables,
              %i[network_map_id source_element_id target_element_id],
              unique: true,
              where: "(source_element_id IS NOT NULL AND target_element_id IS NOT NULL)",
              name: "index_network_cables_on_map_source_target_elements",
              if_not_exists: true

    unless foreign_key_exists?(:network_cables, column: :source_element_id)
      add_foreign_key :network_cables, :map_elements, column: :source_element_id, on_delete: :nullify
    end

    unless foreign_key_exists?(:network_cables, column: :target_element_id)
      add_foreign_key :network_cables, :map_elements, column: :target_element_id, on_delete: :nullify
    end
  end
end
