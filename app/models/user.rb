# frozen_string_literal: true

class User < ApplicationRecord
  EMAIL_REGEX = /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\z/

  normalizes :email, with: ->(email) { email.strip.downcase }

  # Associations
  has_many :borrowings, dependent: :destroy
  has_many :borrowed_items, through: :borrowings, source: :item

  # Validations
  validates :first_name, :last_name, :email, :card_number, presence: true
  validates :email, format: { with: EMAIL_REGEX }, allow_blank: true
  validates :email, uniqueness: true
  validates :card_number, uniqueness: true
end
