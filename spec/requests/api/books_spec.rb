# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books", type: :request do
  let(:json) { response.parsed_body }

  describe "GET /api/books" do
    it "returns an empty list when there are no books" do
      get api_books_path

      expect(response).to have_http_status(:ok)
      expect(json).to eq([])
    end

    it "lists books ordered by id with their data" do
      first = create(:book, title: "First", author2_first_name: "Dave", author2_last_name: "Thomas")
      second = create(:book, title: "Second")

      get api_books_path

      expect(json.pluck("id")).to eq([ first.id, second.id ])
      expect(json.first).to include(
        "serial_number" => first.serial_number, "title" => "First",
        "author1" => "Andrew Hunt", "author2" => "Dave Thomas"
      )
    end

    it "marks a never borrowed book as available without a due date" do
      create(:book)

      get api_books_path

      expect(json.first).to include("status" => "available", "due_date" => nil)
    end

    it "marks a book with an active borrowing as borrowed with its due date" do
      borrowing = create(:borrowing)

      get api_books_path

      expect(json.first).to include("status" => "borrowed", "due_date" => borrowing.due_date.iso8601)
    end

    it "marks an overdue unreturned book as borrowed" do
      create(:borrowing, borrow_date: Date.current - Borrowing::BORROW_TIME_LIMIT - 1.day)

      get api_books_path

      expect(json.first["status"]).to eq("borrowed")
    end

    it "marks a book whose borrowings are all returned as available" do
      create(:borrowing, borrow_date: Date.current - 10.days, return_date: Date.current)

      get api_books_path

      expect(json.first).to include("status" => "available", "due_date" => nil)
    end

    it "reports the status of each book independently" do
      borrowed = create(:borrowing).item
      available = create(:book)

      get api_books_path

      statuses = json.to_h { |book| [ book["id"], book["status"] ] }
      expect(statuses).to eq(borrowed.id => "borrowed", available.id => "available")
    end
  end

  describe "POST /api/books" do
    let(:params) { { book: { title: "Refactoring", author1_first_name: "Martin", author1_last_name: "Fowler" } } }

    it "creates a book and returns it as available" do
      expect { post api_books_path, params: }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include("title" => "Refactoring", "status" => "available")
      expect(json["serial_number"]).to match(/\A\d{6}\z/)
    end

    it "accepts a second author" do
      params[:book].merge!(author2_first_name: "Kent", author2_last_name: "Beck")

      post(api_books_path, params:)

      expect(Book.last).to have_attributes(author2_first_name: "Kent", author2_last_name: "Beck")
    end

    it "ignores attributes that are not permitted" do
      params[:book].merge!(serial_number: "123456", id: 999)

      post(api_books_path, params:)

      expect(Book.last.serial_number).not_to eq("123456")
      expect(Book.last.id).not_to eq(999)
    end

    it "returns errors and does not save when required attributes are missing" do
      params[:book][:title] = ""

      expect { post api_books_path, params: }.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq("title" => [ "Title can't be blank" ])
    end

    it "returns bad request when the book key is missing" do
      post api_books_path, params: { title: "Refactoring" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/books/:id" do
    let!(:book) { create(:book) }

    it "deletes the book" do
      expect { delete api_book_path(book) }.to change(Book, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "deletes the book's borrowings but not other ones" do
      create(:borrowing, item: book)
      other = create(:borrowing)

      expect { delete api_book_path(book) }.to change(Borrowing, :count).by(-1)
      expect(Borrowing.exists?(other.id)).to be(true)
    end

    it "returns not found for an unknown book" do
      expect { delete api_book_path(id: 0) }.not_to change(Book, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
