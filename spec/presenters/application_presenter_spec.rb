# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPresenter do
  let(:presenter_class) do
    Class.new(described_class) do
      def as_json(*) = { title: }
    end
  end
  let(:book) { build(:book, title: "Refactoring") }

  subject(:presenter) { presenter_class.new(book) }

  it "delegates public methods to the wrapped object" do
    expect(presenter.title).to eq("Refactoring")
    expect(presenter).to respond_to(:title)
  end

  it "does not respond to methods the wrapped object lacks" do
    expect(presenter).not_to respond_to(:unknown_method)
    expect { presenter.unknown_method }.to raise_error(NoMethodError)
  end

  it "serializes through the presenter's as_json instead of the model's" do
    expect(JSON.parse(presenter.to_json)).to eq("title" => "Refactoring")
  end

  it "exposes the wrapped object" do
    expect(presenter.__getobj__).to be(book)
  end
end
