module Bootstrap
  class EnsureMasterUser
    Result = Struct.new(:email, :created, :password_updated, keyword_init: true)

    def initialize(email:, password:)
      @email = email.to_s.strip.downcase
      @password = password.to_s
    end

    def call
      raise ArgumentError, "MASTER_USER_EMAIL is required" if email.blank?
      raise ArgumentError, "MASTER_USER_PASSWORD is required" if password.blank?

      user = User.find_or_initialize_by(email: email)
      created = user.new_record?

      if created || password.present?
        user.password = password
        user.password_confirmation = password
      end

      user.admin = true
      user.save!

      Result.new(
        email: user.email,
        created: created,
        password_updated: true
      )
    end

    private

    attr_reader :email, :password
  end
end
