# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

admin_email = ENV.fetch("DEFAULT_ADMIN_EMAIL", "admin@zabbix-map.local")
admin_password = ENV["DEFAULT_ADMIN_PASSWORD"].presence || "ZbxMap!#{SecureRandom.alphanumeric(20)}"

admin_user = User.find_or_initialize_by(email: admin_email)
admin_user.password = admin_password if admin_user.new_record?
admin_user.password_confirmation = admin_password if admin_user.new_record?
admin_user.admin = true
admin_user.save!

puts "Default admin ensured: #{admin_email}"
puts "Default admin password: #{admin_password}" if ENV["DEFAULT_ADMIN_PASSWORD"].blank?
