class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :serial_number, null: false
      t.string :title, null: false
      t.string :author1_first_name, null: false
      t.string :author1_last_name, null: false
      t.string :author2_first_name
      t.string :author2_last_name

      t.timestamps
    end

    add_index :books, :serial_number, unique: true
  end
end
