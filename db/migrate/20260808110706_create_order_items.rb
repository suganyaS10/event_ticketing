class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, foreign_key: true, null: false, index: true
      t.references :ticket_tier, foreign_key: true, null: false, index: true
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false
      t.integer :total_cents, null: false, default: 0

      t.timestamps
    end
  end
end
