module Api
  module V1
    class OrderItemSerializer < ApplicationSerializer
      fields :quantity, :unit_price_cents, :total_cents

      association :ticket_tier, blueprint: TicketTierSerializer
    end
  end
end
