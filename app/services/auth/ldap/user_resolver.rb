module Auth
  module Ldap
    class UserResolver
      def initialize(config: Auth::Ldap::Config.current)
        @config = config
      end

      def call(email:, login:, name: nil)
        resolved_email = resolve_email(email:, login:)
        user = User.find_by(email: resolved_email)
        return user if user.present?
        return nil unless @config.allow_sign_up?

        password = SecureRandom.base58(24)
        User.create!(
          email: resolved_email,
          password:,
          password_confirmation: password
        )
      end

      private

      def resolve_email(email:, login:)
        return email.to_s.downcase if email.present?

        normalized_login = login.to_s.strip.downcase.gsub(/[^a-z0-9._-]/, "-")
        "ldap-#{normalized_login.presence || 'user'}@local.invalid"
      end
    end
  end
end
