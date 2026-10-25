# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def render_errors(record)
    render json: { errors: record.errors.to_hash(true) }, status: :unprocessable_content
  end
end
