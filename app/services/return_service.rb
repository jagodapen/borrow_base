# frozen_string_literal: true

# Closes an active borrowing with today's return date.
# Returns the borrowing — updated on success, or unchanged with errors when it was already returned.
class ReturnService
  def self.call(borrowing)
    new(borrowing).call
  end

  def initialize(borrowing)
    @borrowing = borrowing
  end

  def call
    if @borrowing.return_date
      @borrowing.errors.add(:base, :already_returned)
      return @borrowing
    end

    @borrowing.update!(return_date: Date.current)
    @borrowing
  end
end
