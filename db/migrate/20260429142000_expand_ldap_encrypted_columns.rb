class ExpandLdapEncryptedColumns < ActiveRecord::Migration[8.0]
  def change
    change_column :ldap_settings, :encrypted_bind_dn, :text
    change_column :ldap_settings, :encrypted_bind_password, :text
  end
end
