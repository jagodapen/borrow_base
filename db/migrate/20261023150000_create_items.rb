class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :type, null: false
      t.string :serial_number, null: false
      # Book attributes; presence is enforced by Book validations since items is a shared STI table
      t.string :title
      t.string :author1_first_name
      t.string :author1_last_name
      t.string :author2_first_name
      t.string :author2_last_name

      t.timestamps
    end

    add_index :items, :type
    add_index :items, :serial_number, unique: true
  end
end
