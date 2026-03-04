module EditorStateParams
  private

  def editor_state_params
    params.require(:editor_state).permit(
      :active_base_layer,
      :history_label,
      :history_index,
      draft_cable: {},
      pops: [ :id, :name, :lat, :lng, :color, { metadata: {} } ],
      markers: [ :id, :label, :node_kind, :lat, :lng, :icon, :color, :size, :zabbix_ref, :pop_id, { metadata: {} } ],
      edges: [ :id, :label, :cable_type, :status, :color, :weight, :pattern, :source_pop_id, :target_pop_id, :source_node_id, :target_node_id,
               { metadata: {} }, { points: [ :position, :lat, :lng ] } ]
    )
  end
end
