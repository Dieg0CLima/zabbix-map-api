module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token]
      reject_unauthorized_connection if token.blank?

      secret = ENV["DEVISE_JWT_SECRET_KEY"].presence ||
               Rails.application.credentials.devise_jwt_secret_key!

      payload = JWT.decode(token, secret, true, algorithms: ["HS256"])
      jti = payload.dig(0, "jti")

      user = User.find_by(jti: jti)
      user || reject_unauthorized_connection
    rescue JWT::DecodeError
      reject_unauthorized_connection
    end
  end
end
