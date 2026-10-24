# frozen_string_literal: true

require "rails_helper"

RSpec.describe Item, type: :model do
  # Item is the STI base class; its behavior is exercised through a concrete subclass
  subject(:item) { build(:book) }

  it { is_expected.to be_valid }

  it "requires a type at the database level" do
    expect { described_class.new.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
  end

  describe "serial_number" do
    it "is generated as a 6-digit number before save" do
      item.save!
      expect(item.serial_number).to match(/\A\d{6}\z/)
    end

    it "is generated on validation so presence passes" do
      expect(item.serial_number).to be_nil
      expect(item).to be_valid
      expect(item.serial_number).to be_present
    end

    it "keeps a serial_number assigned before create" do
      item.serial_number = "123456"
      item.save!
      expect(item.reload.serial_number).to eq("123456")
    end

    it "does not change the serial_number of a persisted record on update" do
      item.save!
      original_serial_number = item.serial_number

      item.touch

      expect(item.reload.serial_number).to eq(original_serial_number)
    end

    it "is invalid when blank on an existing record" do
      item.save!
      item.serial_number = nil
      expect(item).not_to be_valid
      expect(item.errors[:serial_number]).to include("can't be blank")
    end

    it "is invalid when duplicated" do
      create(:book, serial_number: "123456")
      item.serial_number = "123456"
      expect(item).not_to be_valid
      expect(item.errors[:serial_number]).to include("has already been taken")
    end

    it "retries when a generated serial_number is already taken" do
      create(:book, serial_number: "000001")
      allow(SecureRandom).to receive(:random_number).and_return(1, 2)
      item.save!
      expect(item.serial_number).to eq("000002")
    end
  end

  describe "#borrowings" do
    let(:item) { create(:book) }

    it "returns borrowings of the item" do
      borrowing = create(:borrowing, item:)
      create(:borrowing)

      expect(item.borrowings).to contain_exactly(borrowing)
    end

    it "is empty when the item has never been borrowed" do
      create(:borrowing)
      expect(item.borrowings).to be_empty
    end

    it "builds borrowings with the item assigned" do
      borrowing = item.borrowings.build(user: create(:user), borrow_date: Date.current)
      expect(borrowing.item).to eq(item)
      expect(borrowing.item_id).to eq(item.id)
    end

    it "destroys borrowings when the item is destroyed" do
      create(:borrowing, item:)
      expect { item.destroy }.to change(Borrowing, :count).by(-1)
    end
  end

  describe "#borrowers" do
    let(:item) { create(:book) }
    let(:user) { create(:user) }

    it "returns users who borrowed the item" do
      other_user = create(:user)
      create(:borrowing, item:, user:, return_date: Date.current)
      create(:borrowing, item:, user: other_user)
      create(:borrowing)

      expect(item.borrowers).to contain_exactly(user, other_user)
    end
  end
end
