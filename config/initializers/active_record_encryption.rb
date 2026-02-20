# config/initializers/active_record_encryption.rb
Rails.application.config.to_prepare do
  cfg = Rails.application.config.active_record.encryption

  cfg.primary_key        = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
  cfg.deterministic_key  = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
  cfg.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
end
