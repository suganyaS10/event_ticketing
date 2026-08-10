class TicketTier < ApplicationRecord
  validates :name, :price_cents, :currency, :quantity_total, :quantity_sold, presence: true
  validates :name, uniqueness: { scope: :event_id }
  validates_comparison_of :quantity_sold, less_than_or_equal_to: :quantity_total

  belongs_to :event

  has_many :order_items

  def quantity_available
    quantity_total - quantity_sold
  end

  def available?
    quantity_available > 0
  end

  def sale_window_live?(at = Time.current)
    (sale_starts_at.nil? || sale_starts_at <= at) &&
      (sale_ends_at.nil? || sale_ends_at > at)
  end
end
