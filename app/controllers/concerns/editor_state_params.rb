module EditorStateParams
  private

  def editor_state_params
    params.require(:editor_state).permit(
      :active_base_layer,
      :history_label,
      :history_index,
      draft_cable: {},
      elements: [
        :id, :mappable_type, :mappable_id,
        :lat, :lng,
        :icon_override, :color_override, :label_override, :size_override,
        :collapsed, :display_order,
        { metadata: {} }
      ],
      edges: [
        :id, :label, :cable_type, :status, :color, :weight, :pattern,
        :source_element_id, :target_element_id,
        { metadata: {} },
        { points: [ :position, :lat, :lng ] }
      ]
    )
  end
end
