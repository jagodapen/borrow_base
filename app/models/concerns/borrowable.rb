# frozen_string_literal: true

module Borrowable
  extend ActiveSupport::Concern

  included do
    has_many :borrowings, as: :item, dependent: :destroy
    has_many :borrowers, through: :borrowings, source: :user
  end
end
