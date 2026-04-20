Rails.application.config.to_prepare do
  mode = Tenancy::Resolver.tenancy_mode
  Rails.logger.info("[tenancy] mode=#{mode}") if defined?(Rails.logger)
end
