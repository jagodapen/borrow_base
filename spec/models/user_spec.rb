# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to be_valid }

  %i[first_name last_name email card_number].each do |attr|
    it "is invalid without #{attr}" do
      user[attr] = nil
      expect(user).not_to be_valid
      expect(user.errors[attr]).to include("can't be blank")
    end
  end

  describe "email format" do
    it "accepts valid addresses" do
      %w[a@b.co john.doe+tag@example.com].each do |email|
        user.email = email
        expect(user).to be_valid
      end
    end

    it "rejects invalid addresses" do
      ["plainaddress", "@example.com", "john@", "john@example", "john doe@example.com", "a@b@c.com"].each do |email|
        user.email = email
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end
    end
  end

  describe "email normalization" do
    it "strips whitespace and downcases before saving" do
      user.email = "  John.Doe@Example.COM "
      user.save!
      expect(user.reload.email).to eq("john.doe@example.com")
    end
  end

  describe "email uniqueness" do
    it "rejects a duplicate email, ignoring case" do
      create(:user, email: "same@example.com")
      user.email = "SAME@example.com"
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end
  end

  describe "card_number uniqueness" do
    it "rejects a duplicate card_number" do
      create(:user, card_number: "CARD1")
      user.card_number = "CARD1"
      expect(user).not_to be_valid
      expect(user.errors[:card_number]).to include("has already been taken")
    end

    it "allows a different card_number for a different user" do
      create(:user, card_number: "CARD1")
      user.card_number = "CARD2"
      expect(user).to be_valid
    end
  end
end
