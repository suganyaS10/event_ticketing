class Order < ApplicationRecord
  validates :total_cents, :order_ref, presence: true
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  enum :status, {
    initialised: "initialised",
    checked_out: "checked_out",
    paid: "paid",
    cancelled: "cancelled"
  }, validate: true

  belongs_to :event
  belongs_to :customer

  has_many :order_items, dependent: :destroy

  before_validation :generate_order_ref

  private

  def generate_order_ref
    self.order_ref ||= "ORD-#{SecureRandom.hex(8).upcase}"
  end
end
