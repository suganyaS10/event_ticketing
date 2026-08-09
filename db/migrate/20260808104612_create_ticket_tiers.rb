class CreateTicketTiers < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_tiers do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "GBP"
      t.integer :quantity_total, null: false
      t.integer :quantity_sold, null: false, default: 0
      t.datetime :sale_starts_at
      t.datetime :sale_ends_at
      t.text :perks

      t.timestamps
    end

    add_index :ticket_tiers, [ :event_id, :name ], unique: true
    add_check_constraint :ticket_tiers,
      "quantity_sold >= 0 AND quantity_sold <= quantity_total",
      name: "ticket_inventory_within_capacity"
  end
end
