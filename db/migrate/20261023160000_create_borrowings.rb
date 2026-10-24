class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.date :borrow_date, null: false
      t.date :due_date, null: false
      t.date :return_date

      t.timestamps
    end

    add_index :borrowings, :due_date
    add_index :borrowings, [ :item_type, :item_id ],
              unique: true,
              where: "return_date IS NULL",
              name: "index_borrowings_on_active_item"
  end
end
