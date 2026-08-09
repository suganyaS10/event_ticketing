class TicketTier < ApplicationRecord
  validates :name, :price_cents, :currency, :quantity_total, :quantity_sold, presence: true
  validates :name, uniqueness: { scope: :event_id }
  validates_comparison_of :quantity_sold, less_than_or_equal_to: :quantity_total

  belongs_to :event

  has_many :order_items
end
