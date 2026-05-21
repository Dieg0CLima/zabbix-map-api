class AddAuthenticationSourceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :authentication_source, :string, null: false, default: "local"
    add_index :users, :authentication_source
  end
end
