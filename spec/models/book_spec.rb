# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  subject(:book) { build(:book) }

  it { is_expected.to be_valid }

  it "includes the Borrowable concern" do
    expect(Book.include?(Borrowable)).to be(true)
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

  describe "serial_number" do
    it "is generated as a 6-digit number before save" do
      book.save!
      expect(book.serial_number).to match(/\A\d{6}\z/)
    end

    it "is generated on validation so presence passes" do
      expect(book.serial_number).to be_nil
      expect(book).to be_valid
      expect(book.serial_number).to be_present
    end

    it "keeps a serial_number assigned before create" do
      book.serial_number = "123456"
      book.save!
      expect(book.reload.serial_number).to eq("123456")
    end

    it "does not change the serial_number of a persisted record on update" do
      book.save!
      original_serial_number = book.serial_number

      book.update!(title: "New title")

      expect(book.reload.serial_number).to eq(original_serial_number)
    end

    it "is invalid when blank on an existing record" do
      book.save!
      book.serial_number = nil
      expect(book).not_to be_valid
      expect(book.errors[:serial_number]).to include("can't be blank")
    end

    it "is invalid when duplicated" do
      create(:book, serial_number: "123456")
      book.serial_number = "123456"
      expect(book).not_to be_valid
      expect(book.errors[:serial_number]).to include("has already been taken")
    end

    it "retries when a generated serial_number is already taken" do
      create(:book, serial_number: "000001")
      allow(SecureRandom).to receive(:random_number).and_return(1, 2)
      book.save!
      expect(book.serial_number).to eq("000002")
    end
  end
end
