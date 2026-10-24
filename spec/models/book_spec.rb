# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  subject(:book) { build(:book) }

  it { is_expected.to be_valid }

  it "inherits from Item" do
    expect(described_class.superclass).to eq(Item)
  end

  it "is stored in the items table with its type" do
    book.save!
    expect(Item.find(book.id)).to be_a(described_class)
    expect(book.reload.type).to eq("Book")
  end

  it "generates a serial_number on create" do
    book.save!
    expect(book.serial_number).to match(/\A\d{6}\z/)
  end

  %i[title author1_first_name author1_last_name].each do |attr|
    it "is invalid without #{attr}" do
      book[attr] = nil
      expect(book).not_to be_valid
      expect(book.errors[attr]).to include("can't be blank")
    end
  end

  it "is valid without a second author" do
    book.assign_attributes(author2_first_name: nil, author2_last_name: nil)
    expect(book).to be_valid
  end

  it "keeps its serial_number when updated" do
    book.save!
    original_serial_number = book.serial_number

    book.update!(title: "New title")

    expect(book.reload.serial_number).to eq(original_serial_number)
  end

  it "has borrowings and borrowers through Item" do
    borrowing = create(:borrowing, item: book)
    expect(book.borrowings).to contain_exactly(borrowing)
    expect(book.borrowers).to contain_exactly(borrowing.user)
  end
end
