# frozen_string_literal: true

class Book < ApplicationRecord
  include Borrowable

  before_validation :generate_serial_number, on: :create

  validates :serial_number, :title, :author1_first_name, :author1_last_name, presence: true
  validates :serial_number, uniqueness: true

  private

  def generate_serial_number
    return if serial_number.present?

    self.serial_number = loop do
      candidate = format("%06d", SecureRandom.random_number(1_000_000))
      break candidate unless Book.exists?(serial_number: candidate)
    end
  end
end
