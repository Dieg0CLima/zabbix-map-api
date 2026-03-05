class AddSiteIdToMapPops < ActiveRecord::Migration[8.0]
  def change
    add_reference :map_pops, :site, null: true, foreign_key: true
  end
end
