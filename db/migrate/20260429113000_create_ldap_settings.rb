class CreateLdapSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :ldap_settings do |t|
      t.boolean :enabled, default: false, null: false
      t.boolean :allow_sign_up, default: false, null: false
      t.boolean :fallback_to_database_auth, default: true, null: false

      t.string :host, null: false
      t.integer :port, default: 389, null: false
      t.string :encryption, default: "start_tls", null: false

      t.string :encrypted_bind_dn
      t.string :encrypted_bind_password

      t.string :search_base_dn, null: false
      t.string :search_filter, default: "(sAMAccountName=%{login})", null: false
      t.string :attr_username, default: "sAMAccountName", null: false
      t.string :attr_email, default: "mail", null: false
      t.string :attr_name, default: "displayName", null: false

      t.bigint :updated_by_user_id

      t.timestamps
    end
  end
end
