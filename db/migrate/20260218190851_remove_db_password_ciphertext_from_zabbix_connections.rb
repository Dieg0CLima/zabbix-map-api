class RemoveDbPasswordCiphertextFromZabbixConnections < ActiveRecord::Migration[8.0]
  def change
    remove_column :zabbix_connections, :db_password_ciphertext, :text
  end
end
