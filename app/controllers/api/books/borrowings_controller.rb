# frozen_string_literal: true

module Api
  module Books
    class BorrowingsController < ApplicationController
      before_action :set_book, only: %i[index]

      def index
        borrowings = @book.borrowings.includes(:user).order(borrow_date: :desc, id: :desc).to_a

        render json: BookPresenter.new(@book, borrowings:).as_json.merge(
          borrowings: borrowings.map { |borrowing| BorrowingPresenter.new(borrowing, with_user: true) }
        )
      end

      private

      def set_book
        @book = Book.find(params[:book_id])
      end
    end
  end
end
