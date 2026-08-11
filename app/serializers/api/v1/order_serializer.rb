module Api
  module V1
    class OrderSerializer < ApplicationSerializer
      fields :status, :order_ref, :total_cents, :failure_reason

      association :order_items, blueprint: OrderItemSerializer
      association :customer, blueprint: CustomerSerializer
    end
  end
end
