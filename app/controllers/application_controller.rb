# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    render json: { error: "Not found" }, status: :not_found
  end

  def render_errors(record, status: "not created")
    render json: { status:, error: "unprocessable content", error_message: record.errors.full_messages.to_sentence },
           status: :unprocessable_content
  end
end
