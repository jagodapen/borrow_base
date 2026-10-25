# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books::Borrowings", type: :request do
  let(:book) { create(:book) }
  let(:json) { response.parsed_body }

  describe "GET /api/books/:book_id/borrowings" do
    it "returns the book data with an empty history when never borrowed" do
      get api_book_borrowings_path(book)

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => book.id, "serial_number" => book.serial_number, "title" => book.title,
                              "status" => "available", "borrowings" => [])
    end

    it "returns the full history newest first with borrower data" do
      user = create(:user, first_name: "Ann", last_name: "Lee", email: "ann@example.com")
      old = create(:borrowing, item: book, user:, borrow_date: Date.new(2026, 8, 1), return_date: Date.new(2026, 8, 20))
      current = create(:borrowing, item: book, borrow_date: Date.new(2026, 10, 1))

      get api_book_borrowings_path(book)

      expect(json["borrowings"].pluck("id")).to eq([ current.id, old.id ])
      expect(json["borrowings"].last).to eq(
        "id" => old.id, "item_id" => book.id, "user_id" => user.id,
        "borrow_date" => "2026-08-01", "due_date" => "2026-08-31", "return_date" => "2026-08-20",
        "borrower" => { "first_name" => "Ann", "last_name" => "Lee",
                        "email" => "ann@example.com", "card_number" => user.card_number }
      )
    end

    it "reports the book as borrowed while a borrowing is active" do
      borrowing = create(:borrowing, item: book)

      get api_book_borrowings_path(book)

      expect(json).to include("status" => "borrowed", "due_date" => borrowing.due_date.iso8601)
    end

    it "excludes borrowings of other books" do
      create(:borrowing)

      get api_book_borrowings_path(book)

      expect(json["borrowings"]).to be_empty
    end

    it "returns not found for an unknown book" do
      get api_book_borrowings_path(book_id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
