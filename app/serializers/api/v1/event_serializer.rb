
module Api
  module V1
    class EventSerializer < ::ApplicationSerializer
      identifier :id

      fields :name, :venue, :short_description, :start_time, :end_time

      view :summary do
        field :tickets_available do |event, _options|
          event.tickets_purchaseable?
        end

        field :price_starts_from do |event, _options|
          event.min_ticket_price
        end

        # Assumes all tiers are in same currency.
        field :currency do |event, _options|
          event.ticket_tiers.first.currency
        end
      end

      view :detailed do
        include_view :summary
        fields :description
        association :ticket_tiers, blueprint: TicketTierSerializer
      end
    end
  end
end
