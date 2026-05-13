class Api::V1::BaseController < ApplicationController
  include ApiResponse
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!

  private

  def find_record(scope, id)
    scope.find(id)
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [ { detail: "Record not found" } ])
    nil
  end
end
