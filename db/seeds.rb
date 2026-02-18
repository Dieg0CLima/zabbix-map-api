# db/seeds.rb

# --- Org default ---
org_name = ENV.fetch("DEFAULT_ORG_NAME", "Default Organization")
org_slug = ENV.fetch("DEFAULT_ORG_SLUG", "default")

organization = Organization.find_or_create_by!(slug: org_slug) do |org|
  org.name = org_name
end

# --- Admin global (super admin do sistema) ---
super_admin_email = ENV.fetch("DEFAULT_ADMIN_EMAIL", "admin@zabbix-map.local")
super_admin_password = ENV["DEFAULT_ADMIN_PASSWORD"].presence || "ZbxMap!#{SecureRandom.alphanumeric(20)}"

super_admin = User.find_or_initialize_by(email: super_admin_email)
if super_admin.new_record?
  super_admin.password = super_admin_password
  super_admin.password_confirmation = super_admin_password
end
super_admin.admin = true
super_admin.save!

# --- Admin da organização (outro usuário) ---
org_admin_email = ENV.fetch("DEFAULT_ORG_ADMIN_EMAIL", "org-admin@zabbix-map.local")
org_admin_password = ENV["DEFAULT_ORG_ADMIN_PASSWORD"].presence || "OrgAdmin!#{SecureRandom.alphanumeric(20)}"

org_admin = User.find_or_initialize_by(email: org_admin_email)
if org_admin.new_record?
  org_admin.password = org_admin_password
  org_admin.password_confirmation = org_admin_password
end
org_admin.admin = false if org_admin.respond_to?(:admin=)
org_admin.save!

org_role = ENV.fetch("DEFAULT_ORG_ADMIN_ROLE", "admin")

Membership.find_or_create_by!(user_id: org_admin.id, organization_id: organization.id) do |m|
  m.role = org_role if m.respond_to?(:role=)
end

puts "Default organization ensured: #{organization.name} (#{organization.slug})"
puts "Global admin ensured: #{super_admin_email}"
puts "Org admin ensured: #{org_admin_email}"
puts "Global admin password: #{super_admin_password}" if ENV["DEFAULT_ADMIN_PASSWORD"].blank?
puts "Org admin password: #{org_admin_password}" if ENV["DEFAULT_ORG_ADMIN_PASSWORD"].blank?
