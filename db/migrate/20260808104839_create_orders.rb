class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_enum :order_status, [ 'initialised', 'checked_out', 'paid', 'cancelled' ]

    create_table :orders do |t|
      t.references :event, foreign_key: true, index: true, null: false
      t.references :customer, foreign_key: true, index: true, null: false
      t.string :order_ref, null: false
      t.integer :total_cents, null: false, default: 0
      t.enum :status, enum_type: :order_status, default: 'initialised', null: false

      t.index :order_ref, unique: true

      t.timestamps
    end
  end
end
