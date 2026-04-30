class FixLdapEncryptedColumnNames < ActiveRecord::Migration[8.0]
  def change
    rename_column :ldap_settings, :encrypted_bind_dn, :bind_dn
    rename_column :ldap_settings, :encrypted_bind_password, :bind_password
  end
end
