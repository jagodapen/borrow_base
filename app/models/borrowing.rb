# frozen_string_literal: true

class Borrowing < ApplicationRecord
  BORROW_TIME_LIMIT = 30.days

  # Associations
  belongs_to :user
  belongs_to :item

  # Validations
  validates :borrow_date, :due_date, presence: true
  validate :borrow_date_not_in_future
  validate :item_available_for_borrow, on: :create
  validate :references_unchanged, on: :update

  # Callbacks
  before_validation :set_default_borrow_date, on: :create
  before_validation :calculate_due_date, if: :borrow_date_changed?

  # Scopes
  # Not yet returned, including overdue ones
  scope :active, -> { where(return_date: nil) }

  private

  def set_default_borrow_date
    self.borrow_date ||= Date.current
  end

  def calculate_due_date
    self.due_date = borrow_date && borrow_date + BORROW_TIME_LIMIT
  end

  def borrow_date_not_in_future
    errors.add(:borrow_date, :in_future) if borrow_date&.future?
  end

  def item_available_for_borrow
    return if item.nil?

    errors.add(:item, :already_borrowed) if Borrowing.active.exists?(item:)
  end

  def references_unchanged
    errors.add(:user, :immutable) if user_id_changed?
    errors.add(:item, :immutable) if item_id_changed?
  end
end
