# frozen_string_literal: true

class Book < Item
  validates :title, :author1_first_name, :author1_last_name, presence: true
end
