# frozen_string_literal: true

class Item < ApplicationRecord
  # Associations
  has_many :borrowings, dependent: :destroy
  has_one :active_borrowing, -> { active }, class_name: "Borrowing", inverse_of: :item
  has_many :borrowers, through: :borrowings, source: :user

  # Validations
  validates :serial_number, presence: true
  validates :serial_number, uniqueness: true

  # Callbacks
  before_validation :generate_serial_number, on: :create

  private

  def generate_serial_number
    return if serial_number.present?

    self.serial_number = loop do
      candidate = format("%06d", SecureRandom.random_number(1_000_000))
      break candidate unless Item.exists?(serial_number: candidate)
    end
  end
end
