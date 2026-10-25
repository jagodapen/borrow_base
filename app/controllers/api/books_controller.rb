# frozen_string_literal: true

module Api
  class BooksController < ApplicationController
    before_action :set_book, only: %i[destroy]

    def index
      books = Book.includes(:active_borrowing).order(:author1_last_name, :id)
      render json: books.map { |book| BookPresenter.new(book) }
    end

    def create
      book = Book.new(book_params)
      if book.save
        render json: { status: "success", book: BookPresenter.new(book) }, status: :created
      else
        render_errors(book)
      end
    end

    def destroy
      @book.destroy!
      head :no_content
    end

    private

    def set_book
      @book = Book.find(params[:id])
    end

    def book_params
      params.expect(book: %i[title author1_first_name author1_last_name author2_first_name author2_last_name])
    end
  end
end
