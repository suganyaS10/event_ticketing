module Api
  module V1
    class TicketTierSerializer < ApplicationSerializer
      identifier :id

      fields :name, :price_cents, :currency, :perks, :quantity_available

      field :on_sale do |tier, _options|
        tier.sale_window_live?
      end
    end
  end
end
