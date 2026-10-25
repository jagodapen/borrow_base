# frozen_string_literal: true

class BorrowingPresenter < ApplicationPresenter
  def initialize(borrowing, with_user: false)
    super(borrowing)
    @with_user = with_user
  end

  def as_json(*)
    json = { id:, item_id:, user_id:, borrow_date:, due_date:, return_date: }
    json[:borrower] = user.slice(:first_name, :last_name, :email, :card_number) if @with_user
    json
  end
end
