# frozen_string_literal: true

class BookPresenter < ApplicationPresenter
  STATUS_AVAILABLE = "available"
  STATUS_BORROWED = "borrowed"

  # Pass already-loaded borrowings to derive the active one without an extra query.
  def initialize(book, borrowings: nil)
    super(book)
    @borrowings = borrowings
  end

  def active_borrowing
    return __getobj__.active_borrowing if @borrowings.nil?

    @borrowings.find { |borrowing| borrowing.return_date.nil? }
  end

  def status
    active_borrowing ? STATUS_BORROWED : STATUS_AVAILABLE
  end

  def author1
    full_name(author1_first_name, author1_last_name)
  end

  def author2
    full_name(author2_first_name, author2_last_name)
  end

  def as_json(*)
    {
      id:, serial_number:, title:, author1:, author2:, status:,
      due_date: active_borrowing&.due_date
    }
  end

  private

  def full_name(first_name, last_name)
    [ first_name, last_name ].compact_blank.join(" ").presence
  end
end
