# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookPresenter do
  let(:book) { create(:book, author2_first_name: "Dave", author2_last_name: "Thomas") }

  subject(:presenter) { described_class.new(book) }

  describe "#status" do
    it "is available when the book was never borrowed" do
      expect(presenter.status).to eq("available")
    end

    it "is borrowed when the book has an active borrowing" do
      create(:borrowing, item: book)
      expect(described_class.new(book.reload).status).to eq("borrowed")
    end

    it "is available when all borrowings are returned" do
      create(:borrowing, item: book, return_date: Date.current)
      expect(described_class.new(book.reload).status).to eq("available")
    end
  end

  describe "#active_borrowing" do
    it "loads the active borrowing from the book when no borrowings are given" do
      borrowing = create(:borrowing, item: book)
      expect(described_class.new(book.reload).active_borrowing).to eq(borrowing)
    end

    context "with preloaded associations" do
      it "uses the preloaded active borrowing without querying" do
        create(:borrowing, item: book, borrow_date: Date.current - 40, return_date: Date.current - 20)
        active = create(:borrowing, item: book)
        preloaded = Book.includes(:borrowings, :active_borrowing).find(book.id)
        presenter = described_class.new(preloaded)

        expect(preloaded.association(:active_borrowing)).to be_loaded
        expect(presenter.active_borrowing).to eq(active)
        expect(presenter.status).to eq("borrowed")
      end

      it "is nil when all borrowings are returned" do
        create(:borrowing, item: book, return_date: Date.current)
        presenter = described_class.new(Book.includes(:borrowings, :active_borrowing).find(book.id))

        expect(presenter.active_borrowing).to be_nil
        expect(presenter.as_json).to include(status: "available", due_date: nil)
      end
    end
  end

  describe "#author1" do
    it "joins the first author's first and last name" do
      expect(presenter.author1).to eq("Andrew Hunt")
    end
  end

  describe "#author2" do
    it "joins the second author's first and last name" do
      expect(presenter.author2).to eq("Dave Thomas")
    end

    it "is nil when the book has no second author" do
      book.update!(author2_first_name: nil, author2_last_name: nil)
      expect(presenter.author2).to be_nil
    end

    it "uses only the present part when one name is blank" do
      book.update!(author2_first_name: "", author2_last_name: "Thomas")
      expect(presenter.author2).to eq("Thomas")
    end
  end

  describe "#as_json" do
    it "includes book attributes, status and no due date when available" do
      expect(presenter.as_json).to eq(
        id: book.id, serial_number: book.serial_number, title: "The Pragmatic Programmer",
        author1: "Andrew Hunt", author2: "Dave Thomas",
        status: "available", due_date: nil
      )
    end

    it "includes the active borrowing's due date when borrowed" do
      borrowing = create(:borrowing, item: book)
      expect(described_class.new(book.reload).as_json[:due_date]).to eq(borrowing.due_date)
    end
  end

  it "delegates attributes to the book" do
    expect(presenter.title).to eq(book.title)
    expect(presenter).to respond_to(:title)
    expect(presenter).not_to respond_to(:unknown_method)
  end
end
