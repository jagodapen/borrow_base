# frozen_string_literal: true

module Api
  module Books
    class BorrowingsController < ApplicationController
      before_action :set_book, only: %i[index]

      def index
        borrowings = @book.borrowings.includes(:user).sort_by { |borrowing| [ borrowing.borrow_date, borrowing.id ] }.reverse

        render json: BookPresenter.new(@book).as_json.merge(
          borrowings: borrowings.map { |borrowing| BorrowingPresenter.new(borrowing, with_user: true) }
        )
      end

      private

      def set_book
        @book = Book.includes(:active_borrowing, borrowings: :user).find(params[:book_id])
      end
    end
  end
end
