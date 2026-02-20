class ChangeDbPasswordCiphertextToText < ActiveRecord::Migration[8.0]
  def change
    change_column :zabbix_connections, :db_password_ciphertext, :text
    change_column :zabbix_connections, :api_token_ciphertext, :text
  end
end
