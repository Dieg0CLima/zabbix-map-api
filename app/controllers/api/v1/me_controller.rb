class Api::V1::MeController < ApplicationController
  before_action :authenticate_user!

  def show
    render json: {
      data: {
        id: current_user.id,
        email: current_user.email
      }
    }, status: :ok
  end
end
