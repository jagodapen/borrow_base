# frozen_string_literal: true

# Lends an item to a user, starting today.
# Returns the borrowing — persisted on success, with errors otherwise.
class BorrowService
  def self.call(user_id: nil, item_id: nil)
    new(user_id:, item_id:).call
  end

  def initialize(user_id:, item_id:)
    @user_id = user_id
    @item_id = item_id
  end

  def call
    borrowing = Borrowing.new(user: User.find_by(id: @user_id), item: Item.find_by(id: @item_id), borrow_date: Date.current)
    borrowing.save
    borrowing
  rescue ActiveRecord::RecordNotUnique
    # Another request borrowed the item between validation and insert
    borrowing.errors.add(:item, :already_borrowed)
    borrowing
  end
end
