# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Borrowings", type: :request do
  let(:book) { create(:book) }
  let(:user) { create(:user) }
  let(:json) { response.parsed_body }

  describe "POST /api/borrowings" do
    let(:params) { { borrowing: { user_id: user.id, item_id: book.id } } }

    it "borrows the item for the user starting today" do
      expect { post api_borrowings_path, params: }.to change(Borrowing, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["status"]).to eq("successfully borrowed")
      expect(json["borrowing"]).to include(
        "item_id" => book.id, "user_id" => user.id,
        "borrow_date" => Date.current.iso8601,
        "due_date" => (Date.current + Borrowing::BORROW_TIME_LIMIT).iso8601,
        "return_date" => nil
      )
    end

    it "makes the book borrowed" do
      post(api_borrowings_path, params:)
      get api_books_path

      expect(response.parsed_body.first["status"]).to eq("borrowed")
    end

    it "ignores a borrow_date passed by the client" do
      params[:borrowing][:borrow_date] = (Date.current - 5.days).iso8601

      post(api_borrowings_path, params:)

      expect(Borrowing.last).to have_attributes(borrow_date: Date.current, user:, item: book)
    end

    it "can borrow the book again after it was returned" do
      create(:borrowing, item: book, borrow_date: Date.current - 3.days, return_date: Date.current)

      post(api_borrowings_path, params:)

      expect(response).to have_http_status(:created)
    end

    it "can borrow a book while the user has another book borrowed" do
      create(:borrowing, user:)

      post(api_borrowings_path, params:)

      expect(response).to have_http_status(:created)
    end

    it "returns errors when the book is already borrowed by another user" do
      create(:borrowing, item: book)

      expect { post api_borrowings_path, params: }.not_to change(Borrowing, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error_message"]).to eq("Item is already borrowed")
    end

    it "returns errors when the book is already borrowed by the same user" do
      create(:borrowing, item: book, user:)

      post(api_borrowings_path, params:)

      expect(json["error_message"]).to eq("Item is already borrowed")
    end

    it "returns errors when the item does not exist" do
      params[:borrowing][:item_id] = 0

      expect { post api_borrowings_path, params: }.not_to change(Borrowing, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error_message"]).to eq("Item must exist")
    end

    it "returns errors when the user does not exist" do
      params[:borrowing][:user_id] = 0

      expect { post api_borrowings_path, params: }.not_to change(Borrowing, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error_message"]).to eq("User must exist")
    end

    it "returns errors when the user id is missing" do
      params[:borrowing].delete(:user_id)

      post(api_borrowings_path, params:)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error_message"]).to eq("User must exist")
    end

    it "ignores an item_type passed by the client" do
      params[:borrowing][:item_type] = "User"

      post(api_borrowings_path, params:)

      expect(response).to have_http_status(:created)
      expect(Borrowing.last.item).to eq(book)
    end

    it "returns bad request when no permitted attributes are passed" do
      post api_borrowings_path, params: { borrowing: { foo: "bar" } }

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when the borrowing key is missing" do
      post api_borrowings_path, params: params[:borrowing]

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PATCH /api/borrowings/:id/return" do
    let!(:borrowing) { create(:borrowing, user:, item: book, borrow_date: Date.current - 5.days) }

    it "returns the borrowing with today's return date" do
      patch return_api_borrowing_path(borrowing)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("successfully returned")
      expect(json["borrowing"]).to include("id" => borrowing.id, "return_date" => Date.current.iso8601)
      expect(borrowing.reload.return_date).to eq(Date.current)
    end

    it "returns an overdue borrowing" do
      borrowing.update_columns(borrow_date: Date.current - 40.days, due_date: Date.current - 10.days)

      patch return_api_borrowing_path(borrowing)

      expect(borrowing.reload.return_date).to eq(Date.current)
    end

    it "makes the book available" do
      patch return_api_borrowing_path(borrowing)
      get api_books_path

      expect(response.parsed_body.first["status"]).to eq("available")
    end

    it "ignores attributes passed by the client" do
      patch return_api_borrowing_path(borrowing), params: {
        borrowing: { return_date: (Date.current - 1.day).iso8601, user_id: create(:user).id, item_id: create(:book).id }
      }

      expect(response).to have_http_status(:ok)
      expect(borrowing.reload).to have_attributes(return_date: Date.current, user_id: user.id, item_id: book.id)
    end

    it "does not return other active borrowings" do
      other = create(:borrowing)

      patch return_api_borrowing_path(borrowing)

      expect(other.reload.return_date).to be_nil
    end

    it "returns errors when the borrowing was already returned" do
      borrowing.update!(return_date: Date.current - 1.day)

      patch return_api_borrowing_path(borrowing)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to include("status" => "not returned", "error_message" => "Borrowing is already returned")
      expect(borrowing.reload.return_date).to eq(Date.current - 1.day)
    end

    it "returns not found when the borrowing does not exist" do
      patch return_api_borrowing_path(id: 0)

      expect(response).to have_http_status(:not_found)
      expect(borrowing.reload.return_date).to be_nil
    end
  end

  describe "PATCH /api/borrowings/:id" do
    let!(:borrowing) { create(:borrowing, user:, item: book) }

    it "is not routed and does not return the borrowing" do
      patch "/api/borrowings/#{borrowing.id}"

      expect(response).to have_http_status(:not_found)
      expect(borrowing.reload.return_date).to be_nil
    end
  end
end
