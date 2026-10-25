# frozen_string_literal: true

require "rails_helper"

RSpec.describe BorrowingPresenter do
  let(:user) { create(:user, first_name: "Ann", last_name: "Lee", email: "ann@example.com") }
  let(:borrowing) { create(:borrowing, user:, borrow_date: Date.new(2026, 10, 1)) }

  describe "#as_json" do
    it "includes borrowing attributes without the borrower by default" do
      expect(described_class.new(borrowing).as_json).to eq(
        id: borrowing.id, item_id: borrowing.item_id, user_id: user.id,
        borrow_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 31), return_date: nil
      )
    end

    it "includes borrower data when requested" do
      json = described_class.new(borrowing, with_user: true).as_json

      expect(json[:borrower]).to eq(
        "first_name" => "Ann", "last_name" => "Lee", "email" => "ann@example.com", "card_number" => user.card_number
      )
    end
  end

  it "delegates attributes to the borrowing" do
    presenter = described_class.new(borrowing)

    expect(presenter.due_date).to eq(borrowing.due_date)
    expect(presenter).to respond_to(:due_date)
  end
end
