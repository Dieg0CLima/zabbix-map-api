class Users::Admin::PasswordReset
  def initialize(user:, password:, password_confirmation:)
    @user = user
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    raise ArgumentError, "LDAP users must reset password in Active Directory" if @user.ldap_managed?

    @user.update!(password: @password, password_confirmation: @password_confirmation)
    @user
  end
end
