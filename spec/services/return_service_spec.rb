# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReturnService do
  let(:book) { create(:book) }
  let(:user) { create(:user) }

  context "when the borrowing is active" do
    let!(:borrowing) { create(:borrowing, user:, item: book, borrow_date: Date.current - 5.days) }

    it "sets today's return date and returns the borrowing" do
      result = described_class.call(borrowing)

      expect(result).to eq(borrowing)
      expect(result.errors).to be_empty
      expect(borrowing.reload.return_date).to eq(Date.current)
    end

    it "returns an overdue borrowing" do
      borrowing.update_columns(borrow_date: Date.current - 40.days, due_date: Date.current - 10.days)

      described_class.call(borrowing)

      expect(borrowing.reload.return_date).to eq(Date.current)
    end

    it "does not change earlier returned borrowings of the item" do
      # Skips the availability validation, which would reject it next to the active borrowing
      returned = build(:borrowing, user:, item: book, borrow_date: Date.current - 20.days,
                                   due_date: Date.current + 10.days, return_date: Date.current - 10.days)
      returned.save!(validate: false)

      described_class.call(borrowing)

      expect(returned.reload.return_date).to eq(Date.current - 10.days)
    end

    it "does not change other active borrowings" do
      other = create(:borrowing, user:)

      described_class.call(borrowing)

      expect(other.reload.return_date).to be_nil
    end
  end

  context "when the borrowing was already returned" do
    let!(:borrowing) do
      create(:borrowing, user:, item: book, borrow_date: Date.current - 5.days, return_date: Date.current - 1.day)
    end

    it "returns the borrowing with errors" do
      result = described_class.call(borrowing)

      expect(result).to eq(borrowing)
      expect(result.errors[:base]).to include("Borrowing is already returned")
    end

    it "keeps the original return date" do
      described_class.call(borrowing)

      expect(borrowing.reload.return_date).to eq(Date.current - 1.day)
    end
  end
end
