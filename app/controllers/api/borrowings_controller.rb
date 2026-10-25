# frozen_string_literal: true

module Api
  class BorrowingsController < ApplicationController
    before_action :set_borrowing, only: %i[return]

    def create
      borrowing = BorrowService.call(user_id: borrowing_params[:user_id], item_id: borrowing_params[:item_id])
      if borrowing.errors.empty?
        render json: { status: "successfully borrowed", borrowing: BorrowingPresenter.new(borrowing) }, status: :created
      else
        render_errors(borrowing)
      end
    end

    # Not routed yet. Reserved for editing a borrowing's attributes, e.g. changing the due_date
    # (extending the borrow period). Returning an item is handled by #return.
    # def update
    # end

    def return
      borrowing = ReturnService.call(@borrowing)
      if borrowing.errors.empty?
        render json: { status: "successfully returned", borrowing: BorrowingPresenter.new(borrowing) }
      else
        render_errors(borrowing, status: "not returned")
      end
    end

    private

    def set_borrowing
      @borrowing = Borrowing.find(params[:id])
    end

    def borrowing_params
      params.expect(borrowing: %i[user_id item_id])
    end
  end
end
