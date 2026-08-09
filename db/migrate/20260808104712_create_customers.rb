class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :first_name
      t.string :last_name
      t.string :email, null: false
      t.string :mobile

      t.index :email, unique: true

      t.timestamps
    end
  end
end
