# frozen_string_literal: true

require "rails_helper"

RSpec.describe Borrowable do
  let(:book) { create(:book) }
  let(:user) { create(:user) }

  describe "#borrowings" do
    it "returns borrowings of the item" do
      borrowing = create(:borrowing, item: book)
      create(:borrowing)

      expect(book.borrowings).to contain_exactly(borrowing)
    end

    it "is empty when the item has never been borrowed" do
      create(:borrowing)
      expect(book.borrowings).to be_empty
    end

    it "builds borrowings with the item assigned polymorphically" do
      borrowing = book.borrowings.build(user:, borrow_date: Date.current)
      expect(borrowing.item).to eq(book)
      expect(borrowing.item_type).to eq("Book")
    end

    it "destroys borrowings when the item is destroyed" do
      create(:borrowing, item: book)
      expect { book.destroy }.to change(Borrowing, :count).by(-1)
    end
  end

  describe "#borrowers" do
    it "returns users who borrowed the item" do
      other_user = create(:user)
      create(:borrowing, item: book, user:, return_date: Date.current)
      create(:borrowing, item: book, user: other_user)
      create(:borrowing)

      expect(book.borrowers).to contain_exactly(user, other_user)
    end
  end
end
