class OrderItem < ApplicationRecord
  validates :quantity, :total_cents, :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :tier_belongs_to_order_event

  belongs_to :order
  belongs_to :ticket_tier

  private

  def tier_belongs_to_order_event
    return if order.nil? || ticket_tier.nil?
    return if ticket_tier.event == order.event

    errors.add(:ticket_tier, "must belong to the order's event")
  end
end
