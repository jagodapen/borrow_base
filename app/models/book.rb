# frozen_string_literal: true

class Book < ApplicationRecord
  before_validation :generate_uuid, on: :create

  validates :uuid, :title, :author1_first_name, :author1_last_name, presence: true
  validates :uuid, uniqueness: true

  private

  def generate_uuid
    return if uuid.present?

    self.uuid = loop do
      candidate = format("%06d", SecureRandom.random_number(1_000_000))
      break candidate unless Book.exists?(uuid: candidate)
    end
  end
end
