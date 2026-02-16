class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      # MVP RBAC: pode ser enum no model
      t.string :role, null: false, default: "admin"

      t.timestamps
    end

    add_index :memberships, [ :organization_id, :user_id ], unique: true
    add_index :memberships, [ :user_id, :role ]
  end
end
