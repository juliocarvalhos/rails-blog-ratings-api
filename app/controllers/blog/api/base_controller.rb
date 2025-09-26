class Blog::Api::BaseController < ApplicationController
  protect_from_forgery with: :null_session

  private

  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end

  def render_success(data, status = :ok)
    render json: data, status: status
  end
end
